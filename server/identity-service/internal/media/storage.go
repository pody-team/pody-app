package media

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"mime"
	"path/filepath"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/minio/minio-go/v7"
	"github.com/minio/minio-go/v7/pkg/credentials"
)

var (
	ErrAvatarTooLarge       = errors.New("avatar file is too large")
	ErrAvatarContentType    = errors.New("avatar file type is not supported")
	ErrAvatarStorageOffline = errors.New("avatar storage is not configured")
)

type AvatarStorage interface {
	EnsureBucket(ctx context.Context) error
	UploadAvatar(ctx context.Context, userID, fileName, contentType string, body io.Reader, size int64) (string, error)
}

type Config struct {
	Endpoint       string
	AccessKey      string
	SecretKey      string
	UseSSL         bool
	BucketName     string
	PublicBaseURL  string
	Region         string
	MaxAvatarBytes int64
}

type MinIOAvatarStorage struct {
	client         *minio.Client
	bucketName     string
	publicBaseURL  string
	region         string
	maxAvatarBytes int64
}

func NewMinIOAvatarStorage(cfg Config) (*MinIOAvatarStorage, error) {
	if strings.TrimSpace(cfg.Endpoint) == "" {
		return nil, ErrAvatarStorageOffline
	}
	if strings.TrimSpace(cfg.AccessKey) == "" || strings.TrimSpace(cfg.SecretKey) == "" {
		return nil, errors.New("minio access key and secret key are required")
	}
	if strings.TrimSpace(cfg.BucketName) == "" {
		return nil, errors.New("minio bucket name is required")
	}
	if strings.TrimSpace(cfg.PublicBaseURL) == "" {
		return nil, errors.New("minio public base url is required")
	}

	client, err := minio.New(cfg.Endpoint, &minio.Options{
		Creds:  credentials.NewStaticV4(cfg.AccessKey, cfg.SecretKey, ""),
		Secure: cfg.UseSSL,
		Region: cfg.Region,
	})
	if err != nil {
		return nil, err
	}

	maxAvatarBytes := cfg.MaxAvatarBytes
	if maxAvatarBytes <= 0 {
		maxAvatarBytes = 5 << 20
	}

	return &MinIOAvatarStorage{
		client:         client,
		bucketName:     strings.TrimSpace(cfg.BucketName),
		publicBaseURL:  strings.TrimRight(strings.TrimSpace(cfg.PublicBaseURL), "/"),
		region:         strings.TrimSpace(cfg.Region),
		maxAvatarBytes: maxAvatarBytes,
	}, nil
}

func (s *MinIOAvatarStorage) EnsureBucket(ctx context.Context) error {
	exists, err := s.client.BucketExists(ctx, s.bucketName)
	if err != nil {
		return err
	}

	if !exists {
		if err := s.client.MakeBucket(ctx, s.bucketName, minio.MakeBucketOptions{Region: s.region}); err != nil {
			exists, existsErr := s.client.BucketExists(ctx, s.bucketName)
			if existsErr != nil {
				return existsErr
			}
			if !exists {
				return err
			}
		}
	}

	return s.client.SetBucketPolicy(ctx, s.bucketName, publicReadPolicy(s.bucketName))
}

func (s *MinIOAvatarStorage) UploadAvatar(
	ctx context.Context,
	userID,
	fileName,
	contentType string,
	body io.Reader,
	size int64,
) (string, error) {
	if size <= 0 || size > s.maxAvatarBytes {
		return "", ErrAvatarTooLarge
	}

	contentType = normalizedContentType(fileName, contentType)
	if !isSupportedAvatarType(contentType) {
		return "", ErrAvatarContentType
	}

	extension := extensionForContentType(fileName, contentType)
	objectKey := fmt.Sprintf("avatars/%s/%s%s", strings.TrimSpace(userID), uuid.NewString(), extension)

	_, err := s.client.PutObject(ctx, s.bucketName, objectKey, body, size, minio.PutObjectOptions{
		ContentType: contentType,
	})
	if err != nil {
		return "", err
	}

	return fmt.Sprintf("%s/%s/%s", s.publicBaseURL, s.bucketName, objectKey), nil
}

func normalizedContentType(fileName, contentType string) string {
	contentType = strings.ToLower(strings.TrimSpace(contentType))
	if contentType != "" {
		if mediaType, _, err := mime.ParseMediaType(contentType); err == nil {
			return mediaType
		}
	}

	switch strings.ToLower(filepath.Ext(fileName)) {
	case ".jpg", ".jpeg":
		return "image/jpeg"
	case ".png":
		return "image/png"
	case ".webp":
		return "image/webp"
	case ".gif":
		return "image/gif"
	case ".heic":
		return "image/heic"
	case ".heif":
		return "image/heif"
	default:
		return ""
	}
}

func extensionForContentType(fileName, contentType string) string {
	switch contentType {
	case "image/jpeg":
		return ".jpg"
	case "image/png":
		return ".png"
	case "image/webp":
		return ".webp"
	case "image/gif":
		return ".gif"
	case "image/heic":
		return ".heic"
	case "image/heif":
		return ".heif"
	}

	extension := strings.ToLower(filepath.Ext(fileName))
	if extension == "" {
		return ".bin"
	}
	return extension
}

func isSupportedAvatarType(contentType string) bool {
	switch contentType {
	case "image/jpeg", "image/png", "image/webp", "image/gif", "image/heic", "image/heif":
		return true
	default:
		return false
	}
}

func publicReadPolicy(bucketName string) string {
	payload, _ := json.Marshal(map[string]any{
		"Version": "2012-10-17",
		"Statement": []map[string]any{
			{
				"Effect":    "Allow",
				"Principal": map[string]string{"AWS": "*"},
				"Action":    []string{"s3:GetBucketLocation", "s3:ListBucket"},
				"Resource":  []string{fmt.Sprintf("arn:aws:s3:::%s", bucketName)},
			},
			{
				"Effect":    "Allow",
				"Principal": map[string]string{"AWS": "*"},
				"Action":    []string{"s3:GetObject"},
				"Resource":  []string{fmt.Sprintf("arn:aws:s3:::%s/*", bucketName)},
			},
		},
	})
	return string(payload)
}

func UploadTimeoutContext(parent context.Context) (context.Context, context.CancelFunc) {
	return context.WithTimeout(parent, 30*time.Second)
}
