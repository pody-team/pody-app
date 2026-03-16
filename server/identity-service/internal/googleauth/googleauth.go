package googleauth

import (
	"context"
	"errors"
	"fmt"
	"strings"

	"google.golang.org/api/idtoken"
)

type Identity struct {
	ProviderUserID string
	Email          string
	DisplayName    string
	AvatarURL      string
	EmailVerified  bool
}

type Verifier interface {
	Verify(ctx context.Context, googleIDToken string) (Identity, error)
}

type verifier struct {
	clientIDs []string
}

func NewVerifier(clientIDs []string) Verifier {
	return verifier{clientIDs: clientIDs}
}

func (v verifier) Verify(ctx context.Context, googleIDToken string) (Identity, error) {
	if len(v.clientIDs) == 0 {
		return Identity{}, errors.New("google auth is not configured")
	}

	token := strings.TrimSpace(googleIDToken)
	if token == "" {
		return Identity{}, errors.New("google id token is required")
	}

	var lastErr error
	for _, clientID := range v.clientIDs {
		payload, err := idtoken.Validate(ctx, token, clientID)
		if err != nil {
			lastErr = err
			continue
		}

		identity := Identity{
			ProviderUserID: payload.Subject,
			Email:          claimString(payload.Claims, "email"),
			DisplayName:    claimString(payload.Claims, "name"),
			AvatarURL:      claimString(payload.Claims, "picture"),
			EmailVerified:  claimBool(payload.Claims, "email_verified"),
		}
		if !identity.EmailVerified {
			return Identity{}, errors.New("google email is not verified")
		}

		return identity, nil
	}

	return Identity{}, fmt.Errorf("google token validation failed: %w", lastErr)
}

func claimString(claims map[string]interface{}, key string) string {
	value, _ := claims[key].(string)
	return strings.TrimSpace(value)
}

func claimBool(claims map[string]interface{}, key string) bool {
	value, ok := claims[key].(bool)
	return ok && value
}
