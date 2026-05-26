package config

import (
	"fmt"
	"os"
	"strconv"
	"strings"
	"time"
)

// Config lưu trữ tất cả các thông số cấu hình hoạt động của Identity Service.
type Config struct {
	Port                   string        // Cổng mạng HTTP server của Identity Service (ví dụ: "8081")
	DatabaseURL            string        // Connection string kết nối tới Postgres (bắt buộc)
	JWTSecret              string        // Khóa bí mật dùng để ký và giải mã JWT token (bắt buộc)
	AccessTokenTTL         time.Duration // Thời gian sống của JWT Access Token
	RefreshTokenTTL        time.Duration // Thời gian sống của JWT Refresh Token
	VerificationTTL        time.Duration // Hạn dùng của token xác thực email
	PasswordResetTTL       time.Duration // Hạn dùng của token đặt lại mật khẩu
	KafkaWriteTimeout      time.Duration // Thời gian chờ tối đa khi ghi thông điệp lên Kafka
	OutboxPollInterval     time.Duration // Tần suất quét bảng outbox_events của Publisher
	OutboxRetention        time.Duration // Thời gian lưu giữ tối đa các outbox event đã gửi thành công trước khi dọn dẹp
	OutboxCleanupInterval  time.Duration // Tần suất chạy worker dọn dẹp bảng outbox_events
	ShutdownTimeout        time.Duration // Thời gian tối đa để tắt server an toàn (graceful shutdown)
	GoogleClientIDs        []string      // Danh sách Client ID được phép khi xác thực bằng Google OAuth
	KafkaBrokers           []string      // Danh sách địa chỉ Kafka brokers (bắt buộc)
	KafkaClientID          string        // Định danh client gửi lên Kafka (Client ID)
	VerificationTopic      string        // Topic Kafka chứa sự kiện gửi email xác minh tài khoản
	VerificationURLBase    string        // URL cơ sở làm liên kết gửi qua email để người dùng click xác minh
	PasswordResetTopic     string        // Topic Kafka chứa sự kiện yêu cầu đổi mật khẩu
	OutboxBatchSize        int           // Số lượng outbox event tối đa xử lý trong mỗi lần quét (batch)
	OutboxCleanupBatchSize int           // Số lượng outbox event tối đa xóa trong mỗi lần dọn dẹp (batch)
	MinIOEndpoint          string        // Địa chỉ kết nối tới MinIO Object Storage (ví dụ: "localhost:9000")
	MinIOAccessKey         string        // Access Key (username) đăng nhập MinIO
	MinIOSecretKey         string        // Secret Key (password) đăng nhập MinIO
	MinIOBucketName        string        // Tên bucket lưu trữ ảnh đại diện người dùng
	MinIORegion            string        // Region của MinIO (ví dụ: "us-east-1")
	MinIOPublicBaseURL     string        // URL công khai dùng để truy cập ảnh đại diện từ client
	MinIOUseSSL            bool          // Sử dụng kết nối SSL/TLS bảo mật tới MinIO hay không
	MaxAvatarBytes         int64         // Dung lượng tối đa của file ảnh avatar (mặc định: 5MB)
}

// Load thực hiện đọc toàn bộ cấu hình từ các biến môi trường và trả về Config cùng lỗi nếu thiếu tham số bắt buộc.
func Load() (Config, error) {
	accessTokenTTL, err := durationFromEnv("ACCESS_TOKEN_TTL", 15*time.Minute)
	if err != nil {
		return Config{}, err
	}

	refreshTokenTTL, err := durationFromEnv("REFRESH_TOKEN_TTL", 30*24*time.Hour)
	if err != nil {
		return Config{}, err
	}

	verificationTTL, err := durationFromEnv("EMAIL_VERIFICATION_TTL", 24*time.Hour)
	if err != nil {
		return Config{}, err
	}

	passwordResetTTL, err := durationFromEnv("PASSWORD_RESET_TTL", 2*time.Hour)
	if err != nil {
		return Config{}, err
	}

	kafkaWriteTimeout, err := durationFromEnv("KAFKA_WRITE_TIMEOUT", 5*time.Second)
	if err != nil {
		return Config{}, err
	}

	outboxPollInterval, err := durationFromEnv("OUTBOX_POLL_INTERVAL", time.Second)
	if err != nil {
		return Config{}, err
	}

	outboxRetention, err := durationFromEnv("OUTBOX_RETENTION", 7*24*time.Hour)
	if err != nil {
		return Config{}, err
	}

	outboxCleanupInterval, err := durationFromEnv("OUTBOX_CLEANUP_INTERVAL", time.Hour)
	if err != nil {
		return Config{}, err
	}

	shutdownTimeout, err := durationFromEnv("SHUTDOWN_TIMEOUT", 10*time.Second)
	if err != nil {
		return Config{}, err
	}

	cfg := Config{
		Port:                   stringFromEnv("PORT", "8081"),
		DatabaseURL:            stringFromEnv("DATABASE_URL", ""),
		JWTSecret:              stringFromEnv("JWT_SECRET", "change-me"),
		AccessTokenTTL:         accessTokenTTL,
		RefreshTokenTTL:        refreshTokenTTL,
		VerificationTTL:        verificationTTL,
		PasswordResetTTL:       passwordResetTTL,
		KafkaWriteTimeout:      kafkaWriteTimeout,
		OutboxPollInterval:     outboxPollInterval,
		OutboxRetention:        outboxRetention,
		OutboxCleanupInterval:  outboxCleanupInterval,
		ShutdownTimeout:        shutdownTimeout,
		GoogleClientIDs:        csvFromEnv("GOOGLE_CLIENT_IDS", nil),
		KafkaBrokers:           csvFromEnv("KAFKA_BROKERS", []string{"localhost:9092"}),
		KafkaClientID:          stringFromEnv("KAFKA_CLIENT_ID", "identity-service"),
		VerificationTopic:      stringFromEnv("VERIFICATION_EVENTS_TOPIC", "identity.email.verification.requested"),
		VerificationURLBase:    stringFromEnv("EMAIL_VERIFICATION_URL_BASE", "http://localhost:8080/verify-email/open"),
		PasswordResetTopic:     stringFromEnv("PASSWORD_RESET_EVENTS_TOPIC", "identity.password.reset.requested"),
		OutboxBatchSize:        intFromEnv("OUTBOX_BATCH_SIZE", 20),
		OutboxCleanupBatchSize: intFromEnv("OUTBOX_CLEANUP_BATCH_SIZE", 200),
		MinIOEndpoint:          stringFromEnv("MINIO_ENDPOINT", ""),
		MinIOAccessKey:         stringFromEnv("MINIO_ROOT_USER", ""),
		MinIOSecretKey:         stringFromEnv("MINIO_ROOT_PASSWORD", ""),
		MinIOBucketName:        stringFromEnv("MINIO_AVATAR_BUCKET", "identity-avatars"),
		MinIORegion:            stringFromEnv("MINIO_REGION", "us-east-1"),
		MinIOPublicBaseURL:     stringFromEnv("MINIO_PUBLIC_BASE_URL", ""),
		MinIOUseSSL:            boolFromEnv("MINIO_USE_SSL", false),
		MaxAvatarBytes:         int64FromEnv("IDENTITY_MAX_AVATAR_BYTES", 5<<20),
	}

	// Đảm bảo các tham số cấu hình bắt buộc được cung cấp đầy đủ
	if strings.TrimSpace(cfg.DatabaseURL) == "" {
		return Config{}, fmt.Errorf("DATABASE_URL is required")
	}

	if strings.TrimSpace(cfg.JWTSecret) == "" {
		return Config{}, fmt.Errorf("JWT_SECRET is required")
	}

	if len(cfg.KafkaBrokers) == 0 {
		return Config{}, fmt.Errorf("KAFKA_BROKERS is required")
	}

	return cfg, nil
}

// Addr trả về địa chỉ cổng mạng lắng nghe (ví dụ: ":8081").
func (c Config) Addr() string {
	return ":" + c.Port
}

// stringFromEnv lấy cấu hình dạng chuỗi từ biến môi trường, dùng fallback nếu rỗng.
func stringFromEnv(key, fallback string) string {
	value := strings.TrimSpace(os.Getenv(key))
	if value == "" {
		return fallback
	}

	return value
}

// csvFromEnv lấy mảng các chuỗi ngăn cách bởi dấu phẩy "," từ biến môi trường.
func csvFromEnv(key string, fallback []string) []string {
	value := strings.TrimSpace(os.Getenv(key))
	if value == "" {
		return fallback
	}

	parts := strings.Split(value, ",")
	result := make([]string, 0, len(parts))
	for _, part := range parts {
		part = strings.TrimSpace(part)
		if part != "" {
			result = append(result, part)
		}
	}

	if len(result) == 0 {
		return fallback
	}

	return result
}

// durationFromEnv parse giá trị time.Duration từ biến môi trường, dùng fallback nếu lỗi hoặc rỗng.
func durationFromEnv(key string, fallback time.Duration) (time.Duration, error) {
	value := strings.TrimSpace(os.Getenv(key))
	if value == "" {
		return fallback, nil
	}

	duration, err := time.ParseDuration(value)
	if err != nil {
		return 0, fmt.Errorf("invalid %s: %w", key, err)
	}

	return duration, nil
}

// intFromEnv parse giá trị kiểu int từ biến môi trường.
func intFromEnv(key string, fallback int) int {
	value := strings.TrimSpace(os.Getenv(key))
	if value == "" {
		return fallback
	}

	result, err := strconv.Atoi(value)
	if err != nil || result <= 0 {
		return fallback
	}

	return result
}

// int64FromEnv parse giá trị kiểu int64 từ biến môi trường.
func int64FromEnv(key string, fallback int64) int64 {
	value := strings.TrimSpace(os.Getenv(key))
	if value == "" {
		return fallback
	}

	result, err := strconv.ParseInt(value, 10, 64)
	if err != nil || result <= 0 {
		return fallback
	}

	return result
}

// boolFromEnv parse giá trị kiểu boolean từ biến môi trường (nhận diện "true", "yes", "on", "1", v.v.).
func boolFromEnv(key string, fallback bool) bool {
	value := strings.TrimSpace(strings.ToLower(os.Getenv(key)))
	if value == "" {
		return fallback
	}

	switch value {
	case "1", "true", "yes", "on":
		return true
	case "0", "false", "no", "off":
		return false
	default:
		return fallback
	}
}

