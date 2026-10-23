import { NestFactory } from '@nestjs/core';
import { ValidationPipe } from '@nestjs/common';
import { AppModule } from './app.module';

async function bootstrap() {
    const app = await NestFactory.create(AppModule, { rawBody: true });

    app.setGlobalPrefix('api/v1');
    app.useGlobalPipes(
        new ValidationPipe({
            whitelist: true,
            forbidNonWhitelisted: true,
            transform: true,
        }),
    );

    const allowedOrigins = (process.env.CORS_ORIGINS ?? '')
        .split(',')
        .map((origin) => origin.trim())
        .filter(Boolean);
    if (process.env.NODE_ENV === 'production' && allowedOrigins.length === 0) {
        throw new Error('CORS_ORIGINS must be configured in production');
    }
    app.enableCors({
        origin: (origin, callback) => {
            if (!origin || process.env.NODE_ENV !== 'production' || allowedOrigins.includes(origin)) {
                callback(null, true);
                return;
            }
            callback(new Error('CORS origin is not allowed'), false);
        },
        credentials: true,
    });

    const port = Number(process.env.PORT || 3000);
    await app.listen(port);
}

bootstrap();
