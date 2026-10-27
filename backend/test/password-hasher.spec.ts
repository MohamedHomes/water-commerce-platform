import { hashPassword, verifyPassword } from '../src/auth/password-hasher';

describe('customer password hashing', () => {
    it('hashes and verifies passwords using the shared authentication implementation', async () => {
        const hash = await hashPassword('StrongPass123!');

        expect(hash).toMatch(/^\$2[aby]\$10\$/);
        expect(hash).not.toBe('StrongPass123!');
        await expect(verifyPassword('StrongPass123!', hash)).resolves.toBe(true);
        await expect(verifyPassword('WrongPass123!', hash)).resolves.toBe(false);
    });
});
