package auth

import (
	"crypto/rand"
	"encoding/base64"
	"errors"
	"time"

	"github.com/golang-jwt/jwt/v5"
	"github.com/promex04/pody/server/identity-service/internal/domain"
)

// TokenManager chịu trách nhiệm cấp phát, ký chữ ký và xác thực JWT token.
type TokenManager struct {
	secret          []byte        // Khóa bí mật dùng để ký và xác nhận chữ ký JWT token
	accessTokenTTL  time.Duration // Thời gian hiệu lực của Access Token
	refreshTokenTTL time.Duration // Thời gian hiệu lực của Refresh Token
}

// NewTokenManager khởi tạo một TokenManager với secret key và thời gian hết hạn tương ứng.
func NewTokenManager(secret string, accessTokenTTL, refreshTokenTTL time.Duration) TokenManager {
	return TokenManager{
		secret:          []byte(secret),
		accessTokenTTL:  accessTokenTTL,
		refreshTokenTTL: refreshTokenTTL,
	}
}

// Issue sinh ra cặp Access Token (JWT) và Refresh Token (mã ngẫu nhiên) cho một người dùng cụ thể.
func (m TokenManager) Issue(user domain.User) (domain.Tokens, error) {
	now := time.Now().UTC()
	accessExpiresAt := now.Add(m.accessTokenTTL)
	refreshExpiresAt := now.Add(m.refreshTokenTTL)

	// Tạo các claims (dữ liệu payload) cho Access Token JWT
	token := jwt.NewWithClaims(jwt.SigningMethodHS256, jwt.MapClaims{
		"sub":   user.ID,          // ID người dùng (Subject)
		"email": user.Email,       // Địa chỉ email
		"role":  user.AccountType, // Quyền hạn/loại tài khoản
		"name":  user.DisplayName, // Tên hiển thị
		"exp":   accessExpiresAt.Unix(),
		"iat":   now.Unix(),
	})

	// Ký token bằng thuật toán HMAC-SHA256 với secret key
	accessToken, err := token.SignedString(m.secret)
	if err != nil {
		return domain.Tokens{}, err
	}

	// Sinh một chuỗi token ngẫu nhiên bảo mật cao làm Refresh Token
	refreshToken, err := randomToken(32)
	if err != nil {
		return domain.Tokens{}, err
	}

	return domain.Tokens{
		AccessToken:           accessToken,
		AccessTokenExpiresAt:  accessExpiresAt,
		RefreshToken:          refreshToken,
		RefreshTokenExpiresAt: refreshExpiresAt,
		TokenType:             "Bearer",
	}, nil
}

// Parse giải mã và kiểm tra chữ ký của JWT Access Token, trả về danh sách các claims nếu hợp lệ.
func (m TokenManager) Parse(accessToken string) (jwt.MapClaims, error) {
	claims := jwt.MapClaims{}
	token, err := jwt.ParseWithClaims(accessToken, claims, func(token *jwt.Token) (any, error) {
		// Kiểm tra thuật toán ký của token có khớp với HMAC không
		if _, ok := token.Method.(*jwt.SigningMethodHMAC); !ok {
			return nil, jwt.ErrTokenSignatureInvalid
		}
		return m.secret, nil
	})
	if err != nil || !token.Valid {
		return nil, errors.New("invalid token")
	}

	return claims, nil
}

// randomToken sinh ra chuỗi mã ngẫu nhiên độ dài tùy chọn được mã hóa dưới dạng Base64 URL Safe.
func randomToken(size int) (string, error) {
	buffer := make([]byte, size)
	if _, err := rand.Read(buffer); err != nil {
		return "", err
	}

	return base64.RawURLEncoding.EncodeToString(buffer), nil
}

