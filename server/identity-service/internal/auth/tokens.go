package auth

import (
	"crypto/rand"
	"encoding/base64"
	"errors"
	"time"

	"github.com/golang-jwt/jwt/v5"
	"github.com/promex04/pody/server/identity-service/internal/domain"
)

type TokenManager struct {
	secret          []byte
	accessTokenTTL  time.Duration
	refreshTokenTTL time.Duration
}

func NewTokenManager(secret string, accessTokenTTL, refreshTokenTTL time.Duration) TokenManager {
	return TokenManager{
		secret:          []byte(secret),
		accessTokenTTL:  accessTokenTTL,
		refreshTokenTTL: refreshTokenTTL,
	}
}

func (m TokenManager) Issue(user domain.User) (domain.Tokens, error) {
	now := time.Now().UTC()
	accessExpiresAt := now.Add(m.accessTokenTTL)
	refreshExpiresAt := now.Add(m.refreshTokenTTL)

	token := jwt.NewWithClaims(jwt.SigningMethodHS256, jwt.MapClaims{
		"sub":   user.ID,
		"email": user.Email,
		"role":  user.AccountType,
		"name":  user.DisplayName,
		"exp":   accessExpiresAt.Unix(),
		"iat":   now.Unix(),
	})

	accessToken, err := token.SignedString(m.secret)
	if err != nil {
		return domain.Tokens{}, err
	}

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

func (m TokenManager) Parse(accessToken string) (jwt.MapClaims, error) {
	claims := jwt.MapClaims{}
	token, err := jwt.ParseWithClaims(accessToken, claims, func(token *jwt.Token) (any, error) {
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

func randomToken(size int) (string, error) {
	buffer := make([]byte, size)
	if _, err := rand.Read(buffer); err != nil {
		return "", err
	}

	return base64.RawURLEncoding.EncodeToString(buffer), nil
}
