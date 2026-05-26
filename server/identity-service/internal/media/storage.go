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

// AvatarStorage định nghĩa interface phục vụ upload và quản lý lưu trữ ảnh đại diện của người dùng.
type AvatarStorage interface {
	EnsureBucket(ctx context.Context) error // Khởi tạo và thiết lập quyền cho bucket lưu trữ nếu chưa tồn tại
	UploadAvatar(ctx context.Context, userID, fileName, contentType string, body io.Reader, size int64) (string, error) // Upload file ảnh
}

// Config cấu hình kết nối MinIO/S3.
type Config struct {
	Endpoint       string // Địa chỉ MinIO server (ví dụ: "localhost:9000")
	AccessKey      string // Access key truy cập
	SecretKey      string // Secret key truy cập
	UseSSL         bool   // Sử dụng SSL/TLS
	BucketName     string // Tên bucket lưu ảnh
	PublicBaseURL  string // URL công khai để truy cập file từ client
	Region         string // Region
	MaxAvatarBytes int64  // Dung lượng giới hạn tối đa cho ảnh đại diện
}

// MinIOAvatarStorage implements AvatarStorage cho MinIO Object Storage.
type MinIOAvatarStorage struct {
	client         *minio.Client // Client kết nối thư viện MinIO SDK
	bucketName     string
	publicBaseURL  string
	region         string
	maxAvatarBytes int64
}

// NewMinIOAvatarStorage khởi tạo mới một đối tượng lưu trữ ảnh đại diện MinIOAvatarStorage.
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

	// Khởi tạo MinIO client
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

// EnsureBucket kiểm tra xem bucket của avatar đã tồn tại chưa.
// Nếu chưa, nó sẽ tạo mới bucket đó và gán policy cho phép đọc công khai (public read policy).
func (s *MinIOAvatarStorage) EnsureBucket(ctx context.Context) error {
	exists, err := s.client.BucketExists(ctx, s.bucketName)
	if err != nil {
		return err
	}

	if !exists {
		// Tạo bucket mới nếu chưa có
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

	// Cài đặt Public Read Policy để client có thể xem ảnh qua HTTP trực tiếp
	return s.client.SetBucketPolicy(ctx, s.bucketName, publicReadPolicy(s.bucketName))
}

// UploadAvatar thực hiện đẩy dữ liệu ảnh lên MinIO.
// Nó thực hiện kiểm tra dung lượng và kiểu định dạng ảnh hợp lệ (jpg, png, webp, gif, heic, heif),
// sau đó lưu trữ dưới dạng key: "avatars/[userID]/[uuid].[extension]"
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
	// Sinh key lưu trữ object ngẫu nhiên bằng UUID để tránh trùng lặp ảnh cũ
	objectKey := fmt.Sprintf("avatars/%s/%s%s", strings.TrimSpace(userID), uuid.NewString(), extension)

	// PutObject tải dữ liệu lên bucket MinIO
	_, err := s.client.PutObject(ctx, s.bucketName, objectKey, body, size, minio.PutObjectOptions{
		ContentType: contentType,
	})
	if err != nil {
		return "", err
	}

	// Trả về liên kết URL đầy đủ tới ảnh đại diện vừa upload
	return fmt.Sprintf("%s/%s/%s", s.publicBaseURL, s.bucketName, objectKey), nil
}

// normalizedContentType chuẩn hóa kiểu định dạng của file dựa trên cả header content-type và đuôi mở rộng của file.
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

// extensionForContentType lấy đuôi mở rộng file phù hợp tương ứng với kiểu content-type.
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

// isSupportedAvatarType lọc các loại ảnh được ứng dụng hỗ trợ.
func isSupportedAvatarType(contentType string) bool {
	switch contentType {
	case "image/jpeg", "image/png", "image/webp", "image/gif", "image/heic", "image/heif":
		return true
	default:
		return false
	}
}

// publicReadPolicy tạo chuỗi policy JSON cho phép đọc công khai (Anonymous Read) đối với bucket.
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

// UploadTimeoutContext tạo context timeout 30 giây phục vụ tiến trình upload ảnh.
func UploadTimeoutContext(parent context.Context) (context.Context, context.CancelFunc) {
	return context.WithTimeout(parent, 30*time.Second)
}
