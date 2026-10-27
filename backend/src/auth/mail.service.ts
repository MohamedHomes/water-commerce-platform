import { Injectable, Logger, ServiceUnavailableException } from '@nestjs/common';
import nodemailer, { Transporter } from 'nodemailer';

@Injectable()
export class MailService {
    private readonly logger = new Logger(MailService.name);
    private transporter?: Transporter;

    get isConfigured() {
        return Boolean(process.env.SMTP_HOST && process.env.SMTP_PORT && process.env.SMTP_FROM);
    }

    async sendPasswordResetCode(email: string, token: string): Promise<boolean> {
        if (!this.isConfigured) {
            throw new ServiceUnavailableException('Password recovery email is not configured');
        }
        try {
            const transporter = this.getTransporter();
            await transporter.sendMail({
                from: process.env.SMTP_FROM,
                to: email,
                subject: 'AquaFlow password recovery',
                text: `Use this one-time code to reset your AquaFlow password: ${token}\n\nThe code expires in 15 minutes. If you did not request this, ignore this email.`,
            });
            return true;
        } catch {
            this.logger.error('Password recovery email delivery failed');
            return false;
        }
    }

    private getTransporter() {
        if (!this.transporter) {
            const port = Number(process.env.SMTP_PORT);
            if (!Number.isInteger(port) || port < 1 || port > 65535) {
                throw new Error('SMTP_PORT must be a valid TCP port');
            }
            this.transporter = nodemailer.createTransport({
                host: process.env.SMTP_HOST,
                port,
                secure: port === 465,
                auth: process.env.SMTP_USER
                    ? {
                          user: process.env.SMTP_USER,
                          pass: process.env.SMTP_PASSWORD,
                      }
                    : undefined,
            });
        }
        return this.transporter;
    }
}
