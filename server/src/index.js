import express from 'express';
import morgan from 'morgan';
import cors from 'cors';
import db from './db.js';
import { remindersRouter } from './routes/reminders.js';
import { contactsRouter } from './routes/contacts.js';
import { sosRouter } from './routes/sos.js';
import { authRouter } from './routes/auth.js';

const app = express();
const port = process.env.PORT || 3001;

app.use(cors());
app.use(express.json());
app.use(morgan('dev'));

app.get('/health', (_req, res) => {
  res.json({ status: 'ok', db: 'connected' });
});

app.use('/reminders', remindersRouter);
app.use('/contacts', contactsRouter);
app.use('/sos', sosRouter);
app.use('/auth', authRouter);

app.use((err, _req, res, _next) => {
  console.error(err);
  res.status(500).json({ error: 'internal_error', message: err.message });
});

app.listen(port, () => {
  console.log(`Guardian backend listening on port ${port}`);
});
