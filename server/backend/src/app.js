// src/app.js
require('dotenv').config();
const express = require('express');
const helmet = require('helmet');
const cors = require('cors');
const compression = require('compression');
const morgan = require('morgan');

const ticketsRouter = require('./routes/tickets.routes');
const authRouter = require('./routes/auth.routes');
const errorHandler = require('./middleware/errorHandler');

const app = express();

app.get('/', (req, res) => res.send('<h1>Hello from Smart Queue Backend Team!'));
app.get('/generate_204', (req, res) =>  res.send('<h1>Hello from Smart Queue Backend Team!'));
app.get('/hotspot-detect.html', (req, res) =>  res.send('<h1>Hello from Smart Queue Backend Team!'));

//app.use(helmet());
//app.use(cors({ origin: /* set to allowed origins */ true }));
//app.use(compression(    ));
//app.use(express.json());
//app.use(morgan('combined'));

// API versioning
//app.use('/api/v1/auth', authRouter);
//app.use('/api/v1/tickets', ticketsRouter);

// health
//app.get('/health', (req, res) => res.json({ status: 'ok' }));

// error handler (last)
//app.use(errorHandler);

module.exports = app;