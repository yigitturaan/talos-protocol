"use client";

import { useState, useCallback } from "react";
import { Panel } from "./ui/Panel";
import { Pulse } from "./ui/Pulse";

type BotType = "honest" | "yield" | "liar" | "manip";

type StepStatus = "pending" | "active" | "done" | "error";

interface Step {
  label: string;
  status: StepStatus;
  txLink?: string;
  detail?: string;
}

const botInfo: Record<BotType, { name: string; desc: string; icon: string; color: string }> = {
  honest: {
    name: "HonestBot",
    desc: "Correct price claim. Verification PASSES, swap executes.",
    icon: "✓",
    color: "text-accent-green",
  },
  yield: {
    name: "YieldBot",
    desc: "Deposit action. Verification PASSES, vault deposit.",
    icon: "↑",
    color: "text-accent-green",
  },
  liar: {
    name: "LiarBot",
    desc: "34% wrong price. FAILS, stake slashed!",
    icon: "✗",
    color: "text-accent-red",
  },
  manip: {
    name: "ManipBot",
    desc: "Alters hash post-commit. FAILS, stake slashed!",
    icon: "⚡",
    color: "text-accent-red",
  },
};

export function DemoPanel() {
  const [selectedBot, setSelectedBot] = useState<BotType | null>(null);
  const [running, setRunning] = useState(false);
  const [steps, setSteps] = useState<Step[]>([]);
  const [result, setResult] = useState<{
    passed: boolean;
    user: { address: string; balanceBefore: string; balanceAfter: string };
    agent: { address: string; scoreBefore: number; scoreAfter: number; stakeBefore: string; stakeAfter: string };
    txs: { lock: string; commit: string; verify: string | null };
  } | null>(null);

  const runScenario = useCallback(async () => {
    if (!selectedBot) return;

    setRunning(true);
    setResult(null);
    setSteps([
      { label: "User locking escrow (100 tUSDC)", status: "active" },
      { label: "Agent committing claim", status: "pending" },
      { label: "Verify + Execute", status: "pending" },
    ]);

    try {
      const res = await fetch("/api/demo", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ bot: selectedBot }),
      });

      const data = await res.json();

      if (!res.ok) {
        setSteps([
          { label: "Error occurred", status: "error", detail: data.error },
        ]);
        return;
      }

      const passed = data.passed;

      setSteps([
        {
          label: "User locked escrow (100 tUSDC)",
          status: "done",
          txLink: data.txs.lock,
          detail: `${data.user.address.slice(0, 8)}... → Talos Escrow`,
        },
        {
          label: "Agent committed claim",
          status: "done",
          txLink: data.txs.commit,
          detail: `${data.agent.address.slice(0, 8)}... hash locked`,
        },
        {
          label: passed
            ? "Verification PASSED — trade executed!"
            : "Verification FAILED — escrow refunded, agent penalized!",
          status: passed ? "done" : "error",
          txLink: data.txs.verify,
          detail: passed
            ? "Oracle price matched — user funds released"
            : selectedBot === "manip"
              ? "Hash mismatch — agent caught!"
              : "Oracle price 34% deviation — hard reject",
        },
      ]);

      setResult({
        passed,
        user: data.user,
        agent: data.agent,
        txs: data.txs,
      });
    } catch (err: unknown) {
      const msg = err instanceof Error ? err.message : "Network error";
      setSteps([{ label: "Connection error", status: "error", detail: msg }]);
    } finally {
      setRunning(false);
    }
  }, [selectedBot]);

  return (
    <div className="space-y-2">
      {/* Bot Selection */}
      <Panel title="1. Select Bot" badge="SCENARIO">
        <div className="grid grid-cols-2 gap-2">
          {(Object.entries(botInfo) as [BotType, typeof botInfo.honest][]).map(
            ([key, bot]) => (
              <button
                key={key}
                onClick={() => !running && setSelectedBot(key)}
                disabled={running}
                className={`text-left p-3 rounded-md border transition-all ${
                  selectedBot === key
                    ? "border-accent-purple bg-bg-elevated/60 shadow-sm"
                    : "border-border-subtle/50 hover:border-text-secondary/50"
                } ${running ? "opacity-50 cursor-not-allowed" : "cursor-pointer"}`}
              >
                <div className="flex items-center gap-2 mb-1">
                  <span className={`text-sm ${bot.color}`}>{bot.icon}</span>
                  <span className="text-xs text-text-primary font-bold">
                    {bot.name}
                  </span>
                </div>
                <p className="text-[10px] text-text-secondary leading-tight">
                  {bot.desc}
                </p>
              </button>
            )
          )}
        </div>
      </Panel>

      {/* Execute Button */}
      <Panel title="2. Execute" badge="1 CLICK">
        <button
          onClick={runScenario}
          disabled={!selectedBot || running}
          className={`w-full py-3 rounded-md text-sm font-bold shadow-sm transition-all duration-300 ${
            !selectedBot || running
              ? "bg-bg-elevated/50 text-text-secondary cursor-not-allowed"
              : "bg-accent-purple text-white hover:bg-accent-purple/90 cursor-pointer hover:shadow-md hover:-translate-y-0.5"
          }`}
        >
          {running
            ? "Running... (~5s)"
            : selectedBot
              ? `Run ${botInfo[selectedBot].name}`
              : "Select a bot first"}
        </button>
        {!running && (
          <p className="text-[10px] text-text-secondary mt-2 text-center">
            User and agent are separate wallets — fully automatic, no approvals needed
          </p>
        )}
      </Panel>

      {/* Steps */}
      {steps.length > 0 && (
        <Panel title="3. Commit-Verify-Execute" badge="CVE">
          <div className="space-y-3">
            {steps.map((step, i) => (
              <div key={i} className="flex items-start gap-3">
                <div className="pt-0.5">
                  {step.status === "pending" && (
                    <div className="w-3 h-3 rounded-full border border-border-subtle" />
                  )}
                  {step.status === "active" && (
                    <Pulse color="purple" size="md" />
                  )}
                  {step.status === "done" && (
                    <Pulse color="green" size="md" />
                  )}
                  {step.status === "error" && (
                    <Pulse color="red" size="md" />
                  )}
                </div>
                <div className="flex-1 min-w-0">
                  <p
                    className={`text-sm font-medium ${
                      step.status === "active"
                        ? "text-accent-purple"
                        : step.status === "done"
                          ? "text-accent-green"
                          : step.status === "error"
                            ? "text-accent-red"
                            : "text-text-secondary"
                    }`}
                  >
                    {step.label}
                  </p>
                  {step.detail && (
                    <p className="text-[10px] text-text-secondary mt-0.5">
                      {step.detail}
                    </p>
                  )}
                  {step.txLink && (
                    <a
                      href={step.txLink}
                      target="_blank"
                      rel="noopener noreferrer"
                      className="text-[11px] text-accent-purple hover:text-accent-purple/80 hover:underline transition-colors"
                    >
                      Explorer ↗
                    </a>
                  )}
                </div>
              </div>
            ))}
          </div>
        </Panel>
      )}

      {/* Result */}
      {result && (
        <Panel
          title="Result"
          badge={result.passed ? "PASS" : "FAIL"}
          badgeColor={result.passed ? "text-accent-green" : "text-accent-red"}
        >
          <div className="space-y-3">
            {/* User section */}
            <div className="p-3 rounded-md bg-bg-elevated/30 border border-border-subtle/50">
              <p className="text-[11px] text-accent-purple mb-2 font-semibold tracking-wide">USER</p>
              <div className="flex justify-between text-[11px]">
                <span className="text-text-secondary">Address</span>
                <span className="text-text-primary font-mono">
                  {result.user.address.slice(0, 6)}...{result.user.address.slice(-4)}
                </span>
              </div>
              <div className="flex justify-between text-[11px] mt-1">
                <span className="text-text-secondary">tUSDC Balance</span>
                <span className="text-text-primary">
                  {result.user.balanceBefore} → {result.user.balanceAfter}
                </span>
              </div>
              <div className="flex justify-between text-[11px] mt-1">
                <span className="text-text-secondary">Escrow</span>
                {result.passed ? (
                  <span className="text-accent-purple">100 tUSDC spent on swap</span>
                ) : (
                  <span className="text-accent-green font-bold">100 tUSDC REFUNDED</span>
                )}
              </div>
            </div>

            {/* Agent section */}
            <div className="p-3 rounded-md bg-bg-elevated/30 border border-border-subtle/50">
              <p className="text-[11px] text-accent-amber mb-2 font-semibold tracking-wide">AGENT (Bot)</p>
              <div className="flex justify-between text-[11px]">
                <span className="text-text-secondary">Address</span>
                <span className="text-text-primary font-mono">
                  {result.agent.address.slice(0, 6)}...{result.agent.address.slice(-4)}
                </span>
              </div>
              <div className="flex justify-between text-[11px] mt-1">
                <span className="text-text-secondary">Reputation</span>
                <span
                  className={
                    result.agent.scoreAfter >= result.agent.scoreBefore
                      ? "text-accent-green"
                      : "text-accent-red"
                  }
                >
                  {result.agent.scoreBefore} → {result.agent.scoreAfter}
                </span>
              </div>
              <div className="flex justify-between text-[11px] mt-1">
                <span className="text-text-secondary">Stake</span>
                <span
                  className={
                    result.agent.stakeAfter === result.agent.stakeBefore
                      ? "text-text-primary"
                      : "text-accent-red"
                  }
                >
                  {result.agent.stakeBefore} → {result.agent.stakeAfter} MON
                  {result.agent.stakeAfter !== result.agent.stakeBefore && " (slashed!)"}
                </span>
              </div>
            </div>

            {/* Fund Flow */}
            <div className="p-3 rounded-md bg-bg-base/50 border border-border-subtle/50">
              <p className="text-[11px] text-text-secondary mb-3 font-semibold tracking-wide">FUND FLOW</p>
              {result.passed ? (
                <div className="space-y-1.5">
                  <div className="flex items-center gap-2 text-[11px]">
                    <span className="text-accent-purple">1.</span>
                    <span className="text-text-primary/90">User locked 100 tUSDC → Escrow</span>
                  </div>
                  <div className="flex items-center gap-2 text-[11px]">
                    <span className="text-accent-purple">2.</span>
                    <span className="text-text-primary/90">Agent verified → Escrow released</span>
                  </div>
                  <div className="flex items-center gap-2 text-[11px]">
                    <span className="text-accent-green">3.</span>
                    <span className="text-accent-green font-bold">100 tUSDC → Used for Swap/Deposit</span>
                  </div>
                  <div className="flex items-center gap-2 text-[11px] mt-1 pt-1 border-t border-border-subtle">
                    <span className="text-text-secondary">Result:</span>
                    <span className="text-text-primary">User funds went to TRADE (successful execution)</span>
                  </div>
                </div>
              ) : (
                <div className="space-y-1.5">
                  <div className="flex items-center gap-2 text-[11px]">
                    <span className="text-accent-purple">1.</span>
                    <span className="text-text-primary/90">User locked 100 tUSDC → Escrow</span>
                  </div>
                  <div className="flex items-center gap-2 text-[11px]">
                    <span className="text-accent-red">2.</span>
                    <span className="text-accent-red">Agent verification FAILED → Trade BLOCKED</span>
                  </div>
                  <div className="flex items-center gap-2 text-[11px]">
                    <span className="text-accent-green">3.</span>
                    <span className="text-accent-green font-bold">100 tUSDC → REFUNDED to user!</span>
                  </div>
                  <div className="flex items-center gap-2 text-[11px]">
                    <span className="text-accent-red">4.</span>
                    <span className="text-accent-red">10% of agent stake SLASHED (penalty)</span>
                  </div>
                  <div className="flex items-center gap-2 text-[11px] mt-1 pt-1 border-t border-border-subtle">
                    <span className="text-text-secondary">Result:</span>
                    <span className="text-accent-green font-bold">User UNHARMED — funds returned!</span>
                  </div>
                </div>
              )}
            </div>

            {/* Verdict */}
            {result.passed ? (
              <div className="p-2 rounded-sm bg-accent-green/10 border border-accent-green/30">
                <p className="text-[11px] text-accent-green font-bold">
                  Verification passed!
                </p>
                <p className="text-[10px] text-accent-green/80 mt-0.5">
                  Agent made a correct claim → funds released → trade executed.
                </p>
              </div>
            ) : (
              <div className="p-2 rounded-sm bg-accent-red/10 border border-accent-red/30">
                <p className="text-[11px] text-accent-red font-bold">
                  Verification failed!
                </p>
                <p className="text-[10px] text-accent-red/80 mt-0.5">
                  Agent lied/manipulated → trade blocked → user protected.
                </p>
              </div>
            )}
          </div>
        </Panel>
      )}
    </div>
  );
}
