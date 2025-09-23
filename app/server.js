const express = require('express');
const { Pool } = require('pg');

const app = express();
const port = process.env.PORT || 3000;

const dbConfig = {
  host: process.env.DB_HOST,
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  database: process.env.DB_NAME || 'cloudcart',
  port: process.env.DB_PORT ? parseInt(process.env.DB_PORT, 10) : 5432,
  ssl: false
};

const pool = new Pool(dbConfig);

app.get('/', async (req, res) => {
  try {
    const result = await pool.query('SELECT NOW() as now');
    res.send(`CloudCart is live! DB time: ${result.rows[0].now}`);
  } catch (err) {
    res.status(500).send('DB connection failed: ' + err.message);
  }
});

app.get('/health', (req, res) => res.json({ status: 'ok' }));

app.listen(port, () => console.log(`App listening on port ${port}`));
