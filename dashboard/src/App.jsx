/**
 * Internal ops dashboard for Assessment IV Scenario 1.
 *
 * Rubric features covered:
 *   1) Live polling (every POLL_MS) of gateway aggregate /health
 *   2) Version display per team (service version + deployed model version)
 *   3) Request counts per team and per A/B variant
 *   4) Test-request form → POST /predict/{team} via gateway (proves routing)
 *
 * API base:
 *   - In-cluster (nginx): /api  → proxied to gateway-api.platform.svc
 *   - Local vite: set VITE_API_BASE=http://localhost:18080 (gateway port-forward)
 */
import { useCallback, useEffect, useState } from "react";

const POLL_MS = 7000;

/** Prefer same-origin /api when served from the dashboard nginx container. */
const API_BASE = (import.meta.env.VITE_API_BASE || "/api").replace(/\/$/, "");

const TEAMS = ["fraud", "recommendations", "forecasting"];

const SAMPLE_PAYLOAD = {
  fraud: { transaction_amount: 120.5, merchant_risk: 0.2 },
  recommendations: { user_id: "u-42", top_k: 3 },
  forecasting: { series: [1, 2, 3, 5, 8], horizon: 2 },
};

function App() {
  const [health, setHealth] = useState(null);
  const [lastCheck, setLastCheck] = useState(null);
  const [error, setError] = useState("");
  const [team, setTeam] = useState("fraud");
  const [payloadText, setPayloadText] = useState(
    JSON.stringify(SAMPLE_PAYLOAD.fraud, null, 2)
  );
  const [predictResult, setPredictResult] = useState(null);
  const [predictBusy, setPredictBusy] = useState(false);

  const refresh = useCallback(async () => {
    try {
      const res = await fetch(`${API_BASE}/health`);
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      const data = await res.json();
      setHealth(data);
      setLastCheck(new Date().toLocaleTimeString());
      setError("");
    } catch (err) {
      setError(String(err.message || err));
    }
  }, []);

  // Live polling — required UI feature #1
  useEffect(() => {
    refresh();
    const id = setInterval(refresh, POLL_MS);
    return () => clearInterval(id);
  }, [refresh]);

  useEffect(() => {
    setPayloadText(JSON.stringify(SAMPLE_PAYLOAD[team], null, 2));
  }, [team]);

  async function runPredict(e) {
    e.preventDefault();
    setPredictBusy(true);
    setPredictResult(null);
    try {
      const body = JSON.parse(payloadText);
      const res = await fetch(`${API_BASE}/predict/${team}`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(body),
      });
      const data = await res.json();
      setPredictResult({ ok: res.ok, status: res.status, data });
    } catch (err) {
      setPredictResult({ ok: false, status: 0, data: { error: String(err) } });
    } finally {
      setPredictBusy(false);
    }
  }

  const teams = health?.teams || {};
  const requests = health?.requests || {};
  const variantCounts = requests.by_variant || {};

  return (
    <div className="min-h-screen bg-gradient-to-b from-slate-950 via-slate-900 to-slate-950">
      <header className="border-b border-slate-800/80 bg-slate-950/70 backdrop-blur">
        <div className="mx-auto flex max-w-6xl items-end justify-between gap-4 px-6 py-8">
          <div>
            <p className="text-xs font-semibold uppercase tracking-[0.2em] text-teal-400">
              Internal ops
            </p>
            <h1 className="mt-2 font-display text-3xl font-bold text-white md:text-4xl">
              ML Platform
            </h1>
            <p className="mt-2 max-w-xl text-sm text-slate-400">
              Scenario 1 — fraud, recommendations, and forecasting behind one gateway.
              Polls every {POLL_MS / 1000}s.
            </p>
          </div>
          <div className="text-right text-xs text-slate-400 font-mono">
            <div>gateway v{health?.version || "—"}</div>
            <div>
              A/B {health?.variants?.a || "a"} {health?.weight_a ?? "—"}% /{" "}
              {health?.variants?.b || "b"} {health ? 100 - health.weight_a : "—"}%
            </div>
            <div>last check {lastCheck || "—"}</div>
          </div>
        </div>
      </header>

      <main className="mx-auto max-w-6xl space-y-10 px-6 py-10">
        {error && (
          <div className="rounded-lg border border-rose-500/40 bg-rose-950/40 px-4 py-3 text-sm text-rose-200">
            Gateway unreachable via <code className="font-mono">{API_BASE}</code>: {error}
          </div>
        )}

        {/* Traffic counters — request volume and how the A/B split landed */}
        <section className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
          <div className="rounded-xl border border-slate-800 bg-slate-900/60 p-5">
            <p className="text-xs uppercase tracking-wide text-slate-400">Requests routed</p>
            <p className="mt-2 font-mono text-3xl text-teal-300">{requests.total ?? 0}</p>
          </div>
          <div className="rounded-xl border border-slate-800 bg-slate-900/60 p-5">
            <p className="text-xs uppercase tracking-wide text-slate-400">Failed</p>
            <p
              className={`mt-2 font-mono text-3xl ${
                requests.errors ? "text-rose-300" : "text-slate-300"
              }`}
            >
              {requests.errors ?? 0}
            </p>
          </div>
          {Object.entries(variantCounts).map(([variant, count]) => (
            <div
              key={variant}
              className="rounded-xl border border-slate-800 bg-slate-900/60 p-5"
            >
              <p className="text-xs uppercase tracking-wide text-slate-400">
                variant {variant}
              </p>
              <p className="mt-2 font-mono text-3xl text-slate-200">{count}</p>
            </div>
          ))}
        </section>

        {/* Multi-team health table — owner + version + green/red */}
        <section>
          <h2 className="mb-4 text-lg font-semibold text-slate-100">Team services</h2>
          <div className="overflow-hidden rounded-xl border border-slate-800 bg-slate-900/60">
            <table className="w-full text-left text-sm">
              <thead className="bg-slate-900 text-xs uppercase tracking-wide text-slate-400">
                <tr>
                  <th className="px-4 py-3">Team</th>
                  <th className="px-4 py-3">Owner</th>
                  <th className="px-4 py-3">Status</th>
                  <th className="px-4 py-3">Service</th>
                  <th className="px-4 py-3">Model version</th>
                  <th className="px-4 py-3">Requests</th>
                  <th className="px-4 py-3">SageMaker endpoint</th>
                </tr>
              </thead>
              <tbody>
                {TEAMS.map((name) => {
                  const row = teams[name] || {};
                  const healthy = !!row.healthy;
                  return (
                    <tr key={name} className="border-t border-slate-800">
                      <td className="px-4 py-3 font-mono text-teal-300">{name}</td>
                      <td className="px-4 py-3 text-slate-300">{row.owner || "—"}</td>
                      <td className="px-4 py-3">
                        <span
                          className={
                            healthy
                              ? "rounded-full bg-emerald-500/15 px-2 py-1 text-emerald-300"
                              : "rounded-full bg-rose-500/15 px-2 py-1 text-rose-300"
                          }
                        >
                          {healthy ? "healthy" : row.error ? "unreachable" : "checking…"}
                        </span>
                      </td>
                      <td className="px-4 py-3 font-mono text-slate-300">
                        {row.version || "—"}
                      </td>
                      <td className="px-4 py-3 font-mono text-slate-300">
                        {row.model_version || "—"}
                      </td>
                      <td className="px-4 py-3 font-mono text-slate-300">
                        {row.requests ?? 0}
                      </td>
                      <td className="px-4 py-3 font-mono text-slate-400">
                        {row.endpoint || "—"}
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        </section>

        {/* Test-request panel — proves /predict/{team} routing isolation */}
        <section className="grid gap-6 md:grid-cols-2">
          <form
            onSubmit={runPredict}
            className="rounded-xl border border-slate-800 bg-slate-900/60 p-5"
          >
            <h2 className="mb-4 text-lg font-semibold">Test predict</h2>
            <label className="mb-2 block text-xs uppercase tracking-wide text-slate-400">
              Team
            </label>
            <select
              className="mb-4 w-full rounded-lg border border-slate-700 bg-slate-950 px-3 py-2 text-sm"
              value={team}
              onChange={(e) => setTeam(e.target.value)}
            >
              {TEAMS.map((t) => (
                <option key={t} value={t}>
                  {t}
                </option>
              ))}
            </select>
            <label className="mb-2 block text-xs uppercase tracking-wide text-slate-400">
              JSON body
            </label>
            <textarea
              className="mb-4 h-40 w-full rounded-lg border border-slate-700 bg-slate-950 px-3 py-2 font-mono text-xs text-slate-200"
              value={payloadText}
              onChange={(e) => setPayloadText(e.target.value)}
            />
            <button
              type="submit"
              disabled={predictBusy}
              className="rounded-lg bg-teal-600 px-4 py-2 text-sm font-semibold text-white hover:bg-teal-500 disabled:opacity-50"
            >
              {predictBusy ? "Sending…" : `POST /predict/${team}`}
            </button>
          </form>

          <div className="rounded-xl border border-slate-800 bg-slate-900/60 p-5">
            <h2 className="mb-4 text-lg font-semibold">Response</h2>
            {!predictResult && (
              <p className="text-sm text-slate-500">
                Run a test request. Look for <code className="font-mono">endpoint</code> and{" "}
                <code className="font-mono">variant</code> in the JSON.
              </p>
            )}
            {predictResult && (
              <>
                <p className="mb-2 text-sm">
                  HTTP {predictResult.status}{" "}
                  <span className={predictResult.ok ? "text-emerald-400" : "text-rose-400"}>
                    {predictResult.ok ? "ok" : "error"}
                  </span>
                </p>
                <pre className="max-h-80 overflow-auto rounded-lg bg-slate-950 p-3 font-mono text-xs text-slate-300">
                  {JSON.stringify(predictResult.data, null, 2)}
                </pre>
              </>
            )}
          </div>
        </section>
      </main>
    </div>
  );
}

export default App;
