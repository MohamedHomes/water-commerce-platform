import 'dotenv/config';
import { createInterface } from 'node:readline';
import pg from 'pg';
import { hashPassword } from '../dist/auth/password-hasher.js';

const EMAIL = 'admin@aquaflow.local';
const CONFIRMATION = `RESET ${EMAIL}`;
const DATABASE = 'aquaflow';
const DATABASE_PORT = 5432;

function readInput(prompt, { hidden = false } = {}) {
  if (!process.stdin.isTTY || typeof process.stdin.setRawMode !== 'function') {
    throw new Error('Run this command from an interactive terminal.');
  }

  return new Promise((resolve, reject) => {
    let value = '';
    process.stdout.write(prompt);
    process.stdin.setEncoding('utf8');
    process.stdin.setRawMode(true);
    process.stdin.resume();

    const cleanup = () => {
      process.stdin.off('data', onData);
      process.stdin.setRawMode(false);
      process.stdout.write('\n');
    };
    const onData = (chunk) => {
      for (const character of chunk) {
        if (character === '\u0003') {
          cleanup();
          reject(new Error('Cancelled.'));
          return;
        }
        if (character === '\r' || character === '\n') {
          cleanup();
          resolve(value);
          return;
        }
        if (character === '\u007f' || character === '\b') {
          value = value.slice(0, -1);
          continue;
        }
        if (character >= ' ') {
          value += character;
          if (!hidden) process.stdout.write(character);
        }
      }
    };

    process.stdin.on('data', onData);
  });
}

function validatePassword(password) {
  if (
    password.length < 8 ||
    !/[A-Za-z]/.test(password) ||
    !/\d/.test(password) ||
    !/[^A-Za-z\d]/.test(password)
  ) {
    throw new Error(
      'Password must be at least 8 characters and include an ASCII letter, number, and symbol.',
    );
  }
}

async function main() {
  if (process.env.NODE_ENV === 'production') {
    throw new Error('This password reset is disabled in production.');
  }
  if (!process.argv.includes('--development-only')) {
    throw new Error(
      'Pass --development-only to confirm this local-only operation.',
    );
  }
  if (!process.env.DATABASE_URL) {
    throw new Error('DATABASE_URL is not configured.');
  }

  const { Client } = pg;
  const client = new Client({ connectionString: process.env.DATABASE_URL });
  await client.connect();
  try {
    const target = (
      await client.query(
        'SELECT current_database() AS database, inet_server_addr()::text AS host, inet_server_port() AS port',
      )
    ).rows[0];
    if (
      target.database !== DATABASE ||
      !['127.0.0.1/32', '127.0.0.1'].includes(target.host) ||
      Number(target.port) !== DATABASE_PORT
    ) {
      throw new Error(
        'Refusing to reset a non-local aquaflow database on 127.0.0.1:5432.',
      );
    }

    const account = await client.query(
      `SELECT id, role FROM public.customers
             WHERE lower(email) = lower($1)`,
      [EMAIL],
    );
    if (account.rowCount !== 1 || account.rows[0].role !== 'admin') {
      throw new Error(
        'The expected local administrator account was not found or is not an administrator.',
      );
    }

    const confirmation = await readInput(
      `Type "${CONFIRMATION}" to continue: `,
    );
    if (confirmation !== CONFIRMATION) {
      throw new Error('Confirmation did not match; no changes were made.');
    }
    const password = await readInput('New password (input hidden): ', {
      hidden: true,
    });
    const repeatedPassword = await readInput(
      'Repeat new password (input hidden): ',
      { hidden: true },
    );
    if (password !== repeatedPassword) {
      throw new Error('Passwords did not match; no changes were made.');
    }
    validatePassword(password);

    const passwordHash = await hashPassword(password);
    await client.query('BEGIN');
    try {
      const updated = await client.query(
        `UPDATE public.customers
                 SET password_hash = $1, updated_at = NOW()
                 WHERE id = $2 AND lower(email) = lower($3) AND role = 'admin'`,
        [passwordHash, account.rows[0].id, EMAIL],
      );
      if (updated.rowCount !== 1) {
        throw new Error(
          'The account changed during reset; no password was updated.',
        );
      }
      await client.query('COMMIT');
    } catch (error) {
      await client.query('ROLLBACK');
      throw error;
    }

    console.log(
      `Password reset complete for ${EMAIL}. The existing admin role was preserved.`,
    );
    console.log(
      'The password and hash were not displayed. Sign in with the new password.',
    );
  } finally {
    await client.end();
  }
}

main().catch((error) => {
  const message =
    error instanceof Error ? error.message : 'Unexpected failure.';
  console.error(`Local administrator password reset failed: ${message}`);
  process.exitCode = 1;
});
