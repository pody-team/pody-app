package googleauth

import (
	"context"
	"errors"
	"fmt"
	"strings"

	"google.golang.org/api/idtoken"
)

// Identity chứa thông tin cá nhân của người dùng lấy từ Google sau khi verify thành công.
type Identity struct {
	ProviderUserID string // ID định danh người dùng từ Google (Subject claim)
	Email          string // Email của tài khoản Google
	DisplayName    string // Tên hiển thị trên tài khoản Google
	AvatarURL      string // Đường dẫn ảnh đại diện Google
	EmailVerified  bool   // Trạng thái email đã được Google xác thực chưa
}

// Verifier định nghĩa interface xác thực Google ID Token gửi lên từ client.
type Verifier interface {
	Verify(ctx context.Context, googleIDToken string) (Identity, error)
}

// verifier là implementation cụ thể của Verifier chứa danh sách Google Client ID hợp lệ.
type verifier struct {
	clientIDs []string
}

// NewVerifier khởi tạo một verifier mới dựa trên danh sách Client IDs.
func NewVerifier(clientIDs []string) Verifier {
	return verifier{clientIDs: clientIDs}
}

// Verify thực hiện kiểm tra tính hợp lệ của Google ID Token bằng thư viện chính thức của Google.
// Token sẽ được thử nghiệm tuần tự qua từng Client ID trong danh sách cho đến khi tìm được cấu hình khớp.
func (v verifier) Verify(ctx context.Context, googleIDToken string) (Identity, error) {
	if len(v.clientIDs) == 0 {
		return Identity{}, errors.New("google auth is not configured")
	}

	token := strings.TrimSpace(googleIDToken)
	if token == "" {
		return Identity{}, errors.New("google id token is required")
	}

	var lastErr error
	// Duyệt qua từng client ID cấu hình để xác minh token
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
		// Yêu cầu email Google phải được verify sẵn từ phía Google
		if !identity.EmailVerified {
			return Identity{}, errors.New("google email is not verified")
		}

		return identity, nil
	}

	return Identity{}, fmt.Errorf("google token validation failed: %w", lastErr)
}

// claimString lấy một trường dữ liệu kiểu string từ bản đồ claims.
func claimString(claims map[string]interface{}, key string) string {
	value, _ := claims[key].(string)
	return strings.TrimSpace(value)
}

// claimBool lấy một trường dữ liệu kiểu boolean từ bản đồ claims.
func claimBool(claims map[string]interface{}, key string) bool {
	value, ok := claims[key].(bool)
	return ok && value
}

