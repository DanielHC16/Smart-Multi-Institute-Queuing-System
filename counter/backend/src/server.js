const express = require('express');
const cors = require('cors');
const path = require('path');

const app = express();
const port = 3000;

app.use(cors());
app.use(express.json());

const COUNTERS = { 0: [], 1: [], 2: [] };

function getActiveUser(index) {
	return COUNTERS[index].filter(i => i.status != 'red')
}
function getLeastLoadedCounter() {
	let min = 0;
	for (let i = 1; i < 3; i++) {
		if (getActiveUser(i).length < getActiveUser(min).length) min = i;
	}
	return min;
}

// ---------------- API Routes ----------------
app.get('/counters', (req, res) => {
	res.json(COUNTERS);
});

app.post('/user', (req, res) => {
	const { name } = req.body;
	if (!name) return res.status(400).json({ error: 'Name required' });

	const user = { name, status: null };
	const counterIndex = getLeastLoadedCounter();
	COUNTERS[counterIndex].push(user);

	res.json({ success: true, counter: counterIndex, user });
});

app.patch('/user/:counterIndex/:userIndex', (req, res) => {
	const { counterIndex, userIndex } = req.params;
	const { status } = req.body;

	if (!['green', 'red'].includes(status))
		return res.status(400).json({ error: 'Invalid status' });

	if (!COUNTERS[counterIndex] || !COUNTERS[counterIndex][userIndex])
		return res.status(404).json({ error: 'User not found' });

	COUNTERS[counterIndex][userIndex].status = status;
	res.json({ success: true });
});

app.post('/user/:counterIndex/rotate', (req, res) => {
	const { counterIndex } = req.params;
	if (!COUNTERS[counterIndex] || COUNTERS[counterIndex].length === 0)
		return res.status(404).json({ error: 'No users in counter' });

	COUNTERS[counterIndex].push(COUNTERS[counterIndex].shift());
	res.json({ success: true });
});

app.use(express.static(path.join(__dirname, 'public')));

app.get('/', (req, res) => {
	res.sendFile(path.join(__dirname, 'public', 'index.html'));
});

app.listen(port, () => {
	console.log(`Queue server running at http://localhost:${port}`);
});
