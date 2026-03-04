import { Router } from 'express';
import db from '../db.js';
import { authOptional } from '../middleware/auth.js';

export const contactsRouter = Router();

contactsRouter.use(authOptional);

const listStmt = db.prepare('SELECT * FROM contacts WHERE (user_id IS NULL OR user_id=@user_id) ORDER BY id ASC');
const insertStmt = db.prepare('INSERT INTO contacts (name, phone, relation, user_id) VALUES (@name, @phone, @relation, @user_id)');
const updateStmt = db.prepare('UPDATE contacts SET name=@name, phone=@phone, relation=@relation WHERE id=@id');
const deleteStmt = db.prepare('DELETE FROM contacts WHERE id=?');
const getByIdStmt = db.prepare('SELECT * FROM contacts WHERE id=?');

contactsRouter.get('/', (_req, res) => {
  const userId = _req.user?.id ?? null;
  res.json(listStmt.all({ user_id: userId }));
});

contactsRouter.post('/', (req, res) => {
  const { name, phone, relation = '' } = req.body;
  if (!name || !phone) return res.status(400).json({ error: 'invalid_request', message: 'name and phone required' });
  const userId = req.user?.id ?? null;
  const info = insertStmt.run({ name, phone, relation, user_id: userId });
  res.status(201).json(getByIdStmt.get(info.lastInsertRowid));
});

contactsRouter.put('/:id', (req, res) => {
  const { id } = req.params;
  const existing = getByIdStmt.get(id);
  if (!existing) return res.status(404).json({ error: 'not_found' });
  const userId = req.user?.id ?? null;
  if (existing.user_id && existing.user_id !== userId) return res.status(403).json({ error: 'forbidden' });
  const { name = existing.name, phone = existing.phone, relation = existing.relation } = req.body;
  updateStmt.run({ id, name, phone, relation });
  res.json(getByIdStmt.get(id));
});

contactsRouter.delete('/:id', (req, res) => {
  const existing = getByIdStmt.get(req.params.id);
  const userId = req.user?.id ?? null;
  if (existing && existing.user_id && existing.user_id !== userId) return res.status(403).json({ error: 'forbidden' });
  const { changes } = deleteStmt.run(req.params.id);
  if (!changes) return res.status(404).json({ error: 'not_found' });
  res.json({ ok: true });
});
