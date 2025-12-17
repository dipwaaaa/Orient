// File: functions/src/index.ts
// Deploy dengan: firebase deploy --only functions

import * as functions from "firebase-functions";
import * as nodemailer from "nodemailer";
import * as dotenv from "dotenv";

// Load environment variables dari .env.local
dotenv.config({ path: ".env.local" });

// Initialize transporter dengan env variables
const getTransporter = () => {
  const emailUser = process.env.GMAIL_USER;
  const emailPass = process.env.GMAIL_PASSWORD;

  if (!emailUser || !emailPass) {
    console.error("❌ Missing email credentials in .env.local");
    throw new Error("Email credentials not configured");
  }

  return nodemailer.createTransport({
    service: "gmail",
    auth: {
      user: emailUser,
      pass: emailPass, // Use App Password, not regular password
    },
  });
};

// Cloud Function: Send delete account token via email
export const sendDeleteAccountToken = functions
  .region("asia-southeast1")
  .runWith({
    timeoutSeconds: 60,
    memory: "512MB",
  })
  .https.onCall(async (data, context) => {
    try {
      // Check authentication
      if (!context.auth) {
        throw new functions.https.HttpsError(
          "unauthenticated",
          "User must be authenticated"
        );
      }

      const { email, token } = data;

      // Validate inputs
      if (!email || !token) {
        throw new functions.https.HttpsError(
          "invalid-argument",
          "Email and token are required"
        );
      }

      if (!email.match(/^[^\s@]+@[^\s@]+\.[^\s@]+$/)) {
        throw new functions.https.HttpsError(
          "invalid-argument",
          "Invalid email format"
        );
      }

      if (token.length !== 6 || !/^\d+$/.test(token)) {
        throw new functions.https.HttpsError(
          "invalid-argument",
          "Token must be 6 digits"
        );
      }

      // Log untuk debugging
      console.log(`📧 Sending token to ${email}`);
      console.log(`🔐 Token: ${token}`);

      // Get transporter
      const transporter = getTransporter();

      // Email content
      const mailOptions = {
        from: process.env.GMAIL_USER,
        to: email,
        subject: "Account Deletion Verification - Orient App",
        html: `
          <div style="font-family: Arial, sans-serif; background-color: #f5f5f5; padding: 20px;">
            <div style="max-width: 600px; margin: 0 auto; background-color: white; padding: 30px; border-radius: 8px; box-shadow: 0 2px 8px rgba(0,0,0,0.1);">

              <h2 style="color: #333; margin-bottom: 20px;">⚠️ Account Deletion Verification</h2>

              <p style="color: #666; font-size: 16px; line-height: 1.6;">
                Hi,<br><br>
                You've requested to delete your Orient app account. Use the verification code below to confirm this action.
              </p>

              <div style="background-color: #fff3cd; border-left: 4px solid #ffc107; padding: 16px; margin: 20px 0; border-radius: 4px;">
                <p style="color: #856404; font-weight: bold; margin: 0;">⚠️ Important:</p>
                <p style="color: #856404; margin: 8px 0 0 0;">
                  If you didn't request this, you can ignore this email. Your account is safe.
                </p>
              </div>

              <p style="color: #333; font-size: 14px; margin: 20px 0;">
                <strong>Your verification code:</strong>
              </p>

              <div style="background-color: #f8f9fa; border: 2px dashed #ddd; padding: 20px; text-align: center; margin: 20px 0; border-radius: 8px;">
                <code style="font-size: 32px; font-weight: bold; letter-spacing: 4px; color: #ff6a00; font-family: 'Courier New', monospace;">
                  ${token}
                </code>
              </div>

              <p style="color: #666; font-size: 14px;">
                <strong>Steps to delete your account:</strong>
              </p>
              <ol style="color: #666; font-size: 14px; line-height: 1.8;">
                <li>Go to Profile Settings → Delete Account</li>
                <li>Choose "Verify with Email Token"</li>
                <li>Paste the code above</li>
                <li>Confirm deletion</li>
              </ol>

              <p style="color: #999; font-size: 12px; margin-top: 30px; padding-top: 20px; border-top: 1px solid #eee;">
                This code will expire in <strong>15 minutes</strong>.<br>
                If you have any questions, contact our support team.
              </p>

              <div style="text-align: center; margin-top: 20px; padding-top: 20px; border-top: 1px solid #eee;">
                <p style="color: #999; font-size: 12px; margin: 0;">
                  © 2025 Orient App. All rights reserved.
                </p>
              </div>

            </div>
          </div>
        `,
        text: `
Account Deletion Verification

Your verification code is: ${token}

This code will expire in 15 minutes.

If you didn't request this, you can ignore this email. Your account is safe.
        `,
      };

      // Send email
      const result = await transporter.sendMail(mailOptions);

      console.log(`✅ Email sent successfully to ${email}`);
      console.log(`Message ID: ${result.messageId}`);

      return {
        success: true,
        message: "Verification email sent successfully",
        email: email,
        timestamp: new Date().toISOString(),
      };

    } catch (error) {
      console.error("❌ Error sending email:", error);

      if (error instanceof functions.https.HttpsError) {
        throw error;
      }

      if (error instanceof Error) {
        console.error("Stack:", error.stack);
      }

      throw new functions.https.HttpsError(
        "internal",
        `Failed to send email: ${error instanceof Error ? error.message : String(error)}`
      );
    }
  });

// Optional: Generic email function untuk use case lain
export const sendEmail = functions
  .region("asia-southeast1")
  .runWith({
    timeoutSeconds: 60,
    memory: "512MB",
  })
  .https.onCall(async (data, context) => {
    try {
      if (!context.auth) {
        throw new functions.https.HttpsError(
          "unauthenticated",
          "User must be authenticated"
        );
      }

      const { to, subject, htmlBody, textBody } = data;

      if (!to || !subject || (!htmlBody && !textBody)) {
        throw new functions.https.HttpsError(
          "invalid-argument",
          "Missing required fields: to, subject, and (htmlBody or textBody)"
        );
      }

      const transporter = getTransporter();

      const mailOptions = {
        from: process.env.GMAIL_USER,
        to,
        subject,
        html: htmlBody,
        text: textBody,
      };

      const result = await transporter.sendMail(mailOptions);

      return {
        success: true,
        messageId: result.messageId,
      };

    } catch (error) {
      console.error("Error sending email:", error);
      throw new functions.https.HttpsError(
        "internal",
        error instanceof Error ? error.message : String(error)
      );
    }
  });