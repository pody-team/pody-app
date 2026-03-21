# BACKEND_AUTH_PROPOSAL

## 1) Mục tiêu auth flow
- Đăng nhập đơn giản, dễ tích hợp mobile/web.
- Access token ngắn hạn, refresh token để gia hạn phiên an toàn hơn.
- Logout được 1 thiết bị hiện tại; có thể mở rộng logout-all sau.
- Endpoint rõ ràng, response ổn định, dễ test và monitor.

## 2) Danh sách endpoint
- `POST /v1/auth/login`
- `POST /v1/auth/refresh`
- `POST /v1/auth/logout`
- `GET /v1/auth/me`

## 3) Request/response schema ngắn gọn

### `POST /v1/auth/login`
**Request**
```json
{
  "email": "user@example.com",
  "password": "string",
  "device_name": "iPhone 15"
}
```
**Response 200**
```json
{
  "user": {
    "id": "usr_123",
    "email": "user@example.com",
    "name": "Hieu"
  },
  "access_token": "jwt_or_opaque_token",
  "refresh_token": "secure_refresh_token",
  "expires_in": 3600,
  "token_type": "Bearer"
}
```

### `POST /v1/auth/refresh`
**Request**
```json
{
  "refresh_token": "secure_refresh_token"
}
```
**Response 200**
```json
{
  "access_token": "new_access_token",
  "refresh_token": "rotated_refresh_token",
  "expires_in": 3600,
  "token_type": "Bearer"
}
```

### `POST /v1/auth/logout`
**Request**
```json
{
  "refresh_token": "secure_refresh_token"
}
```
**Response 200**
```json
{
  "success": true
}
```

### `GET /v1/auth/me`
**Header**
- `Authorization: Bearer <access_token>`

**Response 200**
```json
{
  "id": "usr_123",
  "email": "user@example.com",
  "name": "Hieu"
}
```

## 4) Bảng lỗi phổ biến
| HTTP | code | Khi nào xảy ra | Ghi chú |
|---|---|---|---|
| 400 | `INVALID_INPUT` | Thiếu field, email sai format | Validate sớm ở API layer |
| 401 | `INVALID_CREDENTIALS` | Sai email hoặc password | Không leak field nào sai |
| 401 | `TOKEN_EXPIRED` | Access token hết hạn | Client gọi refresh |
| 401 | `INVALID_TOKEN` | Token sai, hỏng, bị revoke | Áp dụng cho access/refresh |
| 403 | `ACCOUNT_DISABLED` | Tài khoản bị khóa/vô hiệu hóa | Cần rule từ business |
| 429 | `TOO_MANY_REQUESTS` | Spam login/refresh | Nên rate limit theo IP + account |

## 5) Open questions cần PM hoặc Tech Lead chốt
1. Login dùng email/password only hay cần social login / OTP ngay phase đầu?
2. Refresh token lưu ở DB theo từng device/session hay dùng stateless hoàn toàn?
3. Logout scope mặc định là current device hay phải hỗ trợ logout-all ngay từ v1?
