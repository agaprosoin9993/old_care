import { Router } from 'express';
import db from '../db.js';
import { authOptional } from '../middleware/auth.js';

export const remindersRouter = Router();

remindersRouter.use(authOptional);

const listStmt = db.prepare('SELECT * FROM reminders WHERE (user_id IS NULL OR user_id=@user_id) ORDER BY time ASC');
const insertStmt = db.prepare('INSERT INTO reminders (title, time, repeating, completed, user_id) VALUES (@title, @time, @repeating, @completed, @user_id)');
const updateStmt = db.prepare('UPDATE reminders SET title=@title, time=@time, repeating=@repeating, completed=@completed WHERE id=@id');
const deleteStmt = db.prepare('DELETE FROM reminders WHERE id=?');
const getByIdStmt = db.prepare('SELECT * FROM reminders WHERE id=?');

remindersRouter.get('/', (_req, res) => {
  const userId = _req.user?.id ?? null;
  const rows = listStmt.all({ user_id: userId });
  res.json(rows);
});

remindersRouter.post('/', (req, res) => {
  const { title, time, repeating = true, completed = false } = req.body;
  if (!title || !time) return res.status(400).json({ error: 'invalid_request', message: 'title and time required' });
  const userId = req.user?.id ?? null;
  const info = insertStmt.run({ title, time, repeating: repeating ? 1 : 0, completed: completed ? 1 : 0, user_id: userId });
  const created = getByIdStmt.get(info.lastInsertRowid);
  res.status(201).json(created);
});

remindersRouter.put('/:id', (req, res) => {
  const { id } = req.params;
  const existing = getByIdStmt.get(id);
  if (!existing) return res.status(404).json({ error: 'not_found' });
  const userId = req.user?.id ?? null;
  if (existing.user_id && existing.user_id !== userId) return res.status(403).json({ error: 'forbidden' });
  const { title = existing.title, time = existing.time, repeating = !!existing.repeating, completed = !!existing.completed } = req.body;
  updateStmt.run({ id, title, time, repeating: repeating ? 1 : 0, completed: completed ? 1 : 0 });
  res.json(getByIdStmt.get(id));
});

remindersRouter.delete('/:id', (req, res) => {
  const existing = getByIdStmt.get(req.params.id);
  const userId = req.user?.id ?? null;
  if (existing && existing.user_id && existing.user_id !== userId) return res.status(403).json({ error: 'forbidden' });
  const { changes } = deleteStmt.run(req.params.id);
  if (!changes) return res.status(404).json({ error: 'not_found' });
  res.json({ ok: true });
});
