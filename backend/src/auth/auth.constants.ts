function readSecret(name: string, developmentValue: string) {
    const value = process.env[name];
    if (process.env.NODE_ENV === 'production' && (!value || value.length < 32)) {
        throw new Error(`${name} must be configured with at least 32 characters in production`);
    }
    return value || developmentValue;
}

export const JWT_SECRET = readSecret('JWT_SECRET', 'aquaflow-dev-secret');
export const JWT_REFRESH_SECRET = readSecret('JWT_REFRESH_SECRET', 'aquaflow-dev-refresh-secret');

function readTtl(name: string, fallback: string) {
    const value = process.env[name] || fallback;
    const match = /^([1-9]\d*)(s|m|h|d)$/.exec(value);
    if (!match) {
        throw new Error(`${name} must be a positive integer followed by s, m, h, or d`);
    }
    const unitSeconds: Record<string, number> = { s: 1, m: 60, h: 3600, d: 86400 };
    const seconds = Number(match[1]) * unitSeconds[match[2]];
    if (!Number.isSafeInteger(seconds)) {
        throw new Error(`${name} exceeds the supported token lifetime`);
    }
    return seconds;
}

export const JWT_EXPIRES_IN = readTtl('JWT_ACCESS_TTL', '15m');
export const REFRESH_TOKEN_TTL = readTtl('JWT_REFRESH_TTL', '7d');
