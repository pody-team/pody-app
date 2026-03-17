import '../../../core/network/api_exception.dart';
import '../data/google_auth_data_source.dart';

String humanizeAuthError(Object error) {
  if (error is ApiException) {
    switch (error.message) {
      case 'invalid credentials':
        return 'Email hoac mat khau khong dung.';
      case 'email is not verified':
        return 'Email nay chua duoc xac thuc. Hay kiem tra hop thu cua ban.';
      case 'user already exists':
        return 'Email nay da duoc dang ky.';
      case 'email, display name, and password with at least 8 characters are required':
        return 'Hay nhap day du thong tin va mat khau toi thieu 8 ky tu.';
      case 'invalid or expired verification token':
        return 'Liên kết xác thực đã hết hạn hoặc không còn hợp lệ.';
      case 'invalid or expired password reset otp':
        return 'Mã OTP đặt lại mật khẩu đã hết hạn hoặc không còn hợp lệ.';
      case 'email, otp, and a new password with at least 8 characters are required':
        return 'Hãy nhập email, mã OTP và mật khẩu mới tối thiểu 8 ký tự.';
      case 'current password and a new password with at least 8 characters are required':
        return 'Hãy nhập mật khẩu hiện tại và mật khẩu mới tối thiểu 8 ký tự.';
      case 'current password is incorrect':
        return 'Mật khẩu hiện tại chưa đúng.';
      case 'password sign-in is not available for this account':
        return 'Tài khoản này đang dùng đăng nhập Google nên chưa thể đổi mật khẩu tại đây.';
      case 'Phien dang nhap da het han. Hay dang nhap lai de tiep tuc.':
        return 'Phiên đăng nhập đã hết hạn. Hãy đăng nhập lại để tiếp tục.';
      default:
        return error.message;
    }
  }

  if (error is GoogleAuthException) {
    return error.message;
  }

  return 'Da co loi xay ra. Vui long thu lai.';
}
