/*
 * Usage store. Uses Postgres when DATABASE_URL is set (Heroku), otherwise an
 * in-memory store for local development. Both expose the same async interface:
 *   init(), recordEvent(event), getStats({ days }).
 *
 * An event is: { type, visitorId, sessionId, path, referrer, userAgent, ipHash, meta }
 */
import pg from 'pg';

const KNOWN_TYPES = ['pageview', 'chat_ready', 'chat_open', 'chat_close', 'settings_open', 'agent_connected'];

function startOfDayUTC(d) {
  return new Date(Date.UTC(d.getUTCFullYear(), d.getUTCMonth(), d.getUTCDate()));
}

function isoDate(d) {
  return startOfDayUTC(d).toISOString().slice(0, 10);
}

/* ---------------------------------------------------------------- Postgres */

class PostgresStore {
  constructor(connectionString) {
    const needsSsl = !/localhost|127\.0\.0\.1/.test(connectionString);
    this.pool = new pg.Pool({
      connectionString,
      ssl: needsSsl ? { rejectUnauthorized: false } : false,
      max: 5,
    });
  }

  async init() {
    await this.pool.query(`
      CREATE TABLE IF NOT EXISTS usage_events (
        id BIGSERIAL PRIMARY KEY,
        type TEXT NOT NULL,
        visitor_id TEXT,
        session_id TEXT,
        path TEXT,
        referrer TEXT,
        user_agent TEXT,
        ip_hash TEXT,
        meta JSONB,
        created_at TIMESTAMPTZ NOT NULL DEFAULT now()
      );
    `);
    await this.pool.query('CREATE INDEX IF NOT EXISTS idx_usage_events_created ON usage_events (created_at);');
    await this.pool.query('CREATE INDEX IF NOT EXISTS idx_usage_events_type ON usage_events (type);');
  }

  async recordEvent(e) {
    await this.pool.query(
      `INSERT INTO usage_events (type, visitor_id, session_id, path, referrer, user_agent, ip_hash, meta)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8)`,
      [e.type, e.visitorId, e.sessionId, e.path, e.referrer, e.userAgent, e.ipHash, e.meta ? JSON.stringify(e.meta) : null]
    );
  }

  async getStats({ days = 30 } = {}) {
    const since = new Date(Date.now() - days * 86400000);

    const totals = await this.pool.query(`
      SELECT
        COUNT(*) FILTER (WHERE type = 'pageview') AS pageviews,
        COUNT(DISTINCT visitor_id) FILTER (WHERE type = 'pageview') AS unique_visitors,
        COUNT(*) FILTER (WHERE type = 'chat_open') AS chat_opens,
        COUNT(*) FILTER (WHERE type = 'agent_connected') AS agent_connects,
        COUNT(*) AS total_events
      FROM usage_events;
    `);

    const windowed = async (interval) => {
      const r = await this.pool.query(
        `SELECT
           COUNT(*) FILTER (WHERE type = 'pageview') AS pageviews,
           COUNT(DISTINCT visitor_id) FILTER (WHERE type = 'pageview') AS unique_visitors,
           COUNT(*) FILTER (WHERE type = 'chat_open') AS chat_opens
         FROM usage_events
         WHERE created_at >= now() - ($1)::interval`,
        [interval]
      );
      return {
        pageviews: Number(r.rows[0].pageviews),
        uniqueVisitors: Number(r.rows[0].unique_visitors),
        chatOpens: Number(r.rows[0].chat_opens),
      };
    };

    const daily = await this.pool.query(
      `SELECT date_trunc('day', created_at) AS day,
              COUNT(*) FILTER (WHERE type = 'pageview') AS pageviews,
              COUNT(DISTINCT visitor_id) FILTER (WHERE type = 'pageview') AS visitors,
              COUNT(*) FILTER (WHERE type = 'chat_open') AS chat_opens
       FROM usage_events
       WHERE created_at >= $1
       GROUP BY 1 ORDER BY 1`,
      [since]
    );

    const referrers = await this.pool.query(`
      SELECT COALESCE(NULLIF(referrer, ''), '(direct)') AS referrer, COUNT(*) AS count
      FROM usage_events WHERE type = 'pageview'
      GROUP BY 1 ORDER BY count DESC LIMIT 10;
    `);

    const paths = await this.pool.query(`
      SELECT COALESCE(NULLIF(path, ''), '/') AS path, COUNT(*) AS count
      FROM usage_events WHERE type = 'pageview'
      GROUP BY 1 ORDER BY count DESC LIMIT 10;
    `);

    const recent = await this.pool.query(`
      SELECT type, path, referrer, created_at
      FROM usage_events ORDER BY created_at DESC LIMIT 25;
    `);

    return this.shape({
      totals: totals.rows[0],
      last24h: await windowed('24 hours'),
      last7d: await windowed('7 days'),
      last30d: await windowed('30 days'),
      dailyRows: daily.rows.map((r) => ({
        date: isoDate(new Date(r.day)),
        pageviews: Number(r.pageviews),
        visitors: Number(r.visitors),
        chatOpens: Number(r.chat_opens),
      })),
      referrers: referrers.rows.map((r) => ({ referrer: r.referrer, count: Number(r.count) })),
      paths: paths.rows.map((r) => ({ path: r.path, count: Number(r.count) })),
      recent: recent.rows.map((r) => ({
        type: r.type,
        path: r.path,
        referrer: r.referrer,
        createdAt: new Date(r.created_at).toISOString(),
      })),
      days,
    });
  }

  shape(raw) {
    return {
      totals: {
        pageviews: Number(raw.totals.pageviews),
        uniqueVisitors: Number(raw.totals.unique_visitors),
        chatOpens: Number(raw.totals.chat_opens),
        agentConnects: Number(raw.totals.agent_connects),
        totalEvents: Number(raw.totals.total_events),
      },
      last24h: raw.last24h,
      last7d: raw.last7d,
      last30d: raw.last30d,
      daily: fillDailySeries(raw.dailyRows, raw.days),
      referrers: raw.referrers,
      paths: raw.paths,
      recent: raw.recent,
    };
  }
}

/* --------------------------------------------------------------- In-memory */

class MemoryStore {
  constructor() {
    this.events = [];
  }

  async init() {}

  async recordEvent(e) {
    this.events.push({ ...e, createdAt: new Date() });
    // Keep memory bounded on long-running local sessions.
    if (this.events.length > 50000) this.events.splice(0, this.events.length - 50000);
  }

  async getStats({ days = 30 } = {}) {
    const now = Date.now();
    const inWindow = (ms) => this.events.filter((e) => now - e.createdAt.getTime() <= ms);
    const agg = (list) => ({
      pageviews: list.filter((e) => e.type === 'pageview').length,
      uniqueVisitors: new Set(list.filter((e) => e.type === 'pageview').map((e) => e.visitorId)).size,
      chatOpens: list.filter((e) => e.type === 'chat_open').length,
    });

    const pageviews = this.events.filter((e) => e.type === 'pageview');
    const byDay = new Map();
    for (const e of pageviews) {
      const key = isoDate(e.createdAt);
      if (!byDay.has(key)) byDay.set(key, { pageviews: 0, visitors: new Set(), chatOpens: 0 });
      byDay.get(key).pageviews += 1;
      byDay.get(key).visitors.add(e.visitorId);
    }
    for (const e of this.events.filter((x) => x.type === 'chat_open')) {
      const key = isoDate(e.createdAt);
      if (!byDay.has(key)) byDay.set(key, { pageviews: 0, visitors: new Set(), chatOpens: 0 });
      byDay.get(key).chatOpens += 1;
    }
    const dailyRows = [...byDay.entries()].map(([date, v]) => ({
      date,
      pageviews: v.pageviews,
      visitors: v.visitors.size,
      chatOpens: v.chatOpens,
    }));

    const tally = (list, key, fallback) => {
      const m = new Map();
      for (const e of list) {
        const k = e[key] || fallback;
        m.set(k, (m.get(k) || 0) + 1);
      }
      return [...m.entries()].map(([k, count]) => ({ [key]: k, count })).sort((a, b) => b.count - a.count).slice(0, 10);
    };

    return {
      totals: {
        pageviews: pageviews.length,
        uniqueVisitors: new Set(pageviews.map((e) => e.visitorId)).size,
        chatOpens: this.events.filter((e) => e.type === 'chat_open').length,
        agentConnects: this.events.filter((e) => e.type === 'agent_connected').length,
        totalEvents: this.events.length,
      },
      last24h: agg(inWindow(86400000)),
      last7d: agg(inWindow(7 * 86400000)),
      last30d: agg(inWindow(30 * 86400000)),
      daily: fillDailySeries(dailyRows, days),
      referrers: tally(pageviews, 'referrer', '(direct)'),
      paths: tally(pageviews, 'path', '/'),
      recent: [...this.events]
        .slice(-25)
        .reverse()
        .map((e) => ({ type: e.type, path: e.path, referrer: e.referrer, createdAt: e.createdAt.toISOString() })),
    };
  }
}

/* ------------------------------------------------------------------ shared */

function fillDailySeries(rows, days) {
  const map = new Map(rows.map((r) => [r.date, r]));
  const out = [];
  for (let i = days - 1; i >= 0; i--) {
    const d = isoDate(new Date(Date.now() - i * 86400000));
    out.push(map.get(d) || { date: d, pageviews: 0, visitors: 0, chatOpens: 0 });
  }
  return out;
}

export function createStore() {
  const url = process.env.DATABASE_URL;
  if (url) {
    console.log('[store] Using Postgres');
    return new PostgresStore(url);
  }
  console.log('[store] DATABASE_URL not set - using in-memory store (data resets on restart)');
  return new MemoryStore();
}

export { KNOWN_TYPES };
