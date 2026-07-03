import 'dart:math';

import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';

import '../config/env.dart';

/// Shared one-time-code generation + Gmail SMTP delivery, used by both the
/// sign-up and forgot-password flows so the OTP mechanism lives in one place.
class OtpMailer {
  const OtpMailer._();

  static final Random _random = Random.secure();
  static const int otpLength = 6;

  /// A zero-padded 6-digit code (000000–999999).
  static String generateOtp() =>
      _random.nextInt(1000000).toString().padLeft(otpLength, '0');

  /// Sends [code] to [toEmail] over Gmail SMTP using the credentials in
  /// `.env.local`. [subject], [greeting] and [intro] let each flow customise
  /// the copy. Throws on any SMTP/network failure.
  static Future<void> sendOtp({
    required String toEmail,
    required String code,
    required String subject,
    required String greeting,
    required String intro,
  }) async {
    // Trim to guard against stray whitespace, and strip spaces from the app
    // password (Google displays it in groups of four).
    final senderEmail = Env.gmailSenderEmail.trim();
    final appPassword = Env.gmailAppPassword.trim().replaceAll(' ', '');
    final smtpServer = gmail(senderEmail, appPassword);

    final message = Message()
      ..from = Address(senderEmail, 'Proximity')
      ..recipients.add(toEmail)
      ..subject = subject
      ..text = '$greeting\n\n$intro\n\nCode: $code\n'
          'It expires in 10 minutes.\n\n'
          'If you did not request this, you can ignore this email.'
      ..html = _buildHtml(code: code, greeting: greeting, intro: intro);

    await send(message, smtpServer, timeout: const Duration(seconds: 25));
  }

  /// Branded HTML email using the app's green palette.
  static String _buildHtml({
    required String code,
    required String greeting,
    required String intro,
  }) {
    final spacedCode = code.split('').join('&nbsp;');
    return '''
<!DOCTYPE html>
<html>
  <body style="margin:0;padding:0;background-color:#f2f4f5;font-family:Helvetica,Arial,sans-serif;">
    <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background-color:#f2f4f5;padding:24px 0;">
      <tr>
        <td align="center">
          <table role="presentation" width="480" cellpadding="0" cellspacing="0" style="max-width:480px;width:100%;background-color:#ffffff;border-radius:20px;overflow:hidden;box-shadow:0 4px 16px rgba(0,0,0,0.06);">
            <tr>
              <td style="background:linear-gradient(135deg,#009F45,#008C3C);padding:28px 32px;">
                <div style="color:#ffffff;font-size:22px;font-weight:800;letter-spacing:0.2px;">Proximity</div>
                <div style="color:#e7f6ec;font-size:13px;margin-top:2px;">Sleep through your commute, not your stop.</div>
              </td>
            </tr>
            <tr>
              <td style="padding:32px;">
                <p style="color:#111111;font-size:16px;margin:0 0 8px;">$greeting</p>
                <p style="color:#7A7A7A;font-size:14px;line-height:1.5;margin:0 0 24px;">$intro</p>
                <div style="text-align:center;margin:0 0 24px;">
                  <div style="display:inline-block;background-color:#f1faf4;border:1.5px solid #009F45;border-radius:14px;padding:16px 28px;">
                    <span style="color:#009F45;font-size:34px;font-weight:800;letter-spacing:8px;">$spacedCode</span>
                  </div>
                </div>
                <p style="color:#7A7A7A;font-size:13px;line-height:1.5;margin:0 0 4px;">
                  This code expires in <strong style="color:#111111;">10 minutes</strong>.
                </p>
                <p style="color:#9E9E9E;font-size:12px;line-height:1.5;margin:16px 0 0;">
                  If you did not request this, you can safely ignore this email.
                </p>
              </td>
            </tr>
            <tr>
              <td style="background-color:#f7f8f9;padding:18px 32px;text-align:center;">
                <span style="color:#9E9E9E;font-size:12px;">&copy; Proximity</span>
              </td>
            </tr>
          </table>
        </td>
      </tr>
    </table>
  </body>
</html>
''';
  }
}
