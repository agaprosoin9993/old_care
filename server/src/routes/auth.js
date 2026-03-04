import { Router } from 'express';
import bcrypt from 'bcryptjs';
import { v4 as uuid } from 'uuid';
import db from '../db.js';
import { authRequired } from '../middleware/auth.js';

export const authRouter = Router();

const getUserByUsername = db.prepare('SELECT * FROM users WHERE username = ?');
const insertUser = db.prepare('INSERT INTO users (username, password_hash, display_name) VALUES (@username, @password_hash, @display_name)');
const insertSession = db.prepare('INSERT INTO sessions (token, user_id, created_at) VALUES (@token, @user_id, @created_at)');
const getSessionUser = db.prepare(
  'SELECT sessions.token, users.id as user_id, users.username, users.display_name FROM sessions JOIN users ON users.id = sessions.user_id WHERE sessions.token = ?'
);

function issueSession(userId) {
  const token = uuid();
  insertSession.run({ token, user_id: userId, created_at: new Date().toISOString() });
  return token;
}

function sanitizeUser(row) {
  return { id: row.id, username: row.username, displayName: row.display_name };
}

authRouter.post('/register', (req, res) => {
  const { username, password, displayName = '' } = req.body;
  if (!username || !password) return res.status(400).json({ error: 'invalid_request', message: 'username & password required' });
  const existed = getUserByUsername.get(username);
  if (existed) return res.status(409).json({ error: 'conflict', message: 'username exists' });
  const password_hash = bcrypt.hashSync(password, 10);
  const info = insertUser.run({ username, password_hash, display_name: displayName });
  const token = issueSession(info.lastInsertRowid);
  res.status(201).json({ token, user: { id: info.lastInsertRowid, username, displayName } });
});

authRouter.post('/login', (req, res) => {
  const { username, password } = req.body;
  if (!username || !password) return res.status(400).json({ error: 'invalid_request' });
  const user = getUserByUsername.get(username);
  if (!user) return res.status(401).json({ error: 'invalid_credentials' });
  const ok = bcrypt.compareSync(password, user.password_hash);
  if (!ok) return res.status(401).json({ error: 'invalid_credentials' });
  const token = issueSession(user.id);
  res.json({ token, user: sanitizeUser(user) });
});

authRouter.get('/me', authRequired, (req, res) => {
  const session = getSessionUser.get(req.user.token);
  if (!session) return res.status(401).json({ error: 'unauthorized' });
  res.json({ user: { id: session.user_id, username: session.username, displayName: session.display_name } });
});
