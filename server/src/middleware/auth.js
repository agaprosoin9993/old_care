import db from '../db.js';

const getSessionStmt = db.prepare(`
SELECT sessions.token, users.id as user_id, users.username, users.display_name
FROM sessions
JOIN users ON users.id = sessions.user_id
WHERE sessions.token = ?
`);

export function authOptional(req, _res, next) {
  const auth = req.headers.authorization || '';
  const token = auth.startsWith('Bearer ') ? auth.slice(7) : null;
  if (token) {
    const row = getSessionStmt.get(token);
    if (row) {
      req.user = { id: row.user_id, username: row.username, displayName: row.display_name, token };
    }
  }
  next();
}

export function authRequired(req, res, next) {
  authOptional(req, res, () => {
    if (!req.user) return res.status(401).json({ error: 'unauthorized' });
    next();
  });
}
