import { Router } from 'express';
import db from '../db.js';
import { authOptional } from '../middleware/auth.js';

export const sosRouter = Router();

sosRouter.use(authOptional);

const listStmt = db.prepare('SELECT * FROM sos_logs WHERE (user_id IS NULL OR user_id=@user_id) ORDER BY created_at DESC LIMIT 50');
const insertStmt = db.prepare('INSERT INTO sos_logs (created_at, location, contact, note, user_id) VALUES (@created_at, @location, @contact, @note, @user_id)');

sosRouter.get('/', (_req, res) => {
  const userId = _req.user?.id ?? null;
  res.json(listStmt.all({ user_id: userId }));
});

sosRouter.post('/', (req, res) => {
  const { location = '', contact = '', note = '' } = req.body;
  const created_at = new Date().toISOString();
  const userId = req.user?.id ?? null;
  const info = insertStmt.run({ created_at, location, contact, note, user_id: userId });
  res.status(201).json({ id: info.lastInsertRowid, created_at, location, contact, note });
});
