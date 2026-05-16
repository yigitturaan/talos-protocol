"use client";

import Link from "next/link";
import { useEffect, useRef, useState } from "react";

function useInView(threshold = 0.2) {
  const ref = useRef<HTMLDivElement>(null);
  const [inView, setInView] = useState(false);

  useEffect(() => {
    const el = ref.current;
    if (!el) return;
    const obs = new IntersectionObserver(
      ([entry]) => { if (entry.isIntersecting) setInView(true); },
      { threshold }
    );
    obs.observe(el);
    return () => obs.disconnect();
  }, [threshold]);

  return { ref, inView };
}

function AnimatedFlow() {
  return (
    <div className="grid grid-cols-2 gap-8 max-w-3xl mx-auto">
      {/* Pass Flow */}
      <div className="relative">
        <p className="text-center text-xs text-accent-green font-bold mb-4 tracking-wider">
          VERIFICATION PASSED
        </p>
        <div className="relative flex flex-col items-center gap-0">
          <FlowNode label="User" sublabel="100 USDC" color="cyan" />
          <FlowArrow color="cyan" />
          <FlowNode label="Escrow" sublabel="Locked" color="cyan" />
          <FlowArrow color="green" />
          <FlowNode label="Talos" sublabel="3 layers OK" color="green" />
          <FlowArrow color="green" />
          <FlowNode label="Swap" sublabel="Executed" color="green" />

          {/* Animated dot */}
          <div className="absolute inset-0 pointer-events-none">
            <div className="relative w-full h-full">
              <div className="flow-dot-pass absolute left-1/2 -translate-x-1/2 w-2 h-2 rounded-full bg-accent-green shadow-[0_0_8px_rgba(63,185,80,0.8)]" />
            </div>
          </div>
        </div>
        <div className="mt-4 text-center">
          <span className="text-[10px] text-accent-green/80">
            Funds released — trade completed
          </span>
        </div>
      </div>

      {/* Fail Flow */}
      <div className="relative">
        <p className="text-center text-xs text-accent-red font-bold mb-4 tracking-wider">
          VERIFICATION FAILED
        </p>
        <div className="relative flex flex-col items-center gap-0">
          <FlowNode label="User" sublabel="100 USDC" color="cyan" />
          <FlowArrow color="cyan" />
          <FlowNode label="Escrow" sublabel="Locked" color="cyan" />
          <FlowArrow color="red" />
          <FlowNode label="Talos" sublabel="REJECT" color="red" />
          <FlowArrowReverse />
          <FlowNode label="User" sublabel="REFUND" color="green" />

          {/* Animated dot */}
          <div className="absolute inset-0 pointer-events-none">
            <div className="relative w-full h-full">
              <div className="flow-dot-fail absolute left-1/2 -translate-x-1/2 w-2 h-2 rounded-full bg-accent-red shadow-[0_0_8px_rgba(248,81,73,0.8)]" />
            </div>
          </div>
        </div>
        <div className="mt-4 text-center">
          <span className="text-[10px] text-accent-green/80">
            Funds RETURNED — user protected
          </span>
        </div>
      </div>
    </div>
  );
}

function FlowNode({ label, sublabel, color }: { label: string; sublabel: string; color: "cyan" | "green" | "red" }) {
  const border = {
    cyan: "border-accent-cyan/40",
    green: "border-accent-green/40",
    red: "border-accent-red/40",
  }[color];
  const text = {
    cyan: "text-accent-cyan",
    green: "text-accent-green",
    red: "text-accent-red",
  }[color];

  return (
    <div className={`w-full max-w-[160px] border ${border} rounded-sm px-3 py-2 bg-bg-panel text-center`}>
      <p className={`text-[11px] font-bold ${text}`}>{label}</p>
      <p className="text-[10px] text-text-secondary">{sublabel}</p>
    </div>
  );
}

function FlowArrow({ color }: { color: "cyan" | "green" | "red" }) {
  const c = {
    cyan: "text-accent-cyan/50",
    green: "text-accent-green/50",
    red: "text-accent-red/50",
  }[color];
  return (
    <div className={`py-1 ${c} text-center text-sm leading-none`}>
      ↓
    </div>
  );
}

function FlowArrowReverse() {
  return (
    <div className="py-1 text-accent-green/50 text-center text-sm leading-none">
      ↑
    </div>
  );
}

const threats = [
  {
    title: "Data Hallucination",
    problem: "Agent claims a wrong price — doesn't match reality",
    solution: "Live comparison against Chainlink oracle feed",
  },
  {
    title: "Post-Commit Tampering",
    problem: "Agent tries to verify with a different claim than committed",
    solution: "Cryptographic hash lock — tampering detected instantly",
  },
  {
    title: "Overspending",
    problem: "Agent tries to drain the entire balance in one trade",
    solution: "Daily/weekly spending limits + max drawdown policy",
  },
  {
    title: "Slippage Manipulation",
    problem: "Agent sets intentionally low minimum output",
    solution: "Market-price-based slippage guard enforcement",
  },
  {
    title: "Unauthorized Contract Access",
    problem: "Agent sends transactions to unknown/malicious contracts",
    solution: "Whitelist — only approved targets allowed",
  },
];

export default function Home() {
  const heroSection = useInView();
  const threatSection = useInView();
  const flowSection = useInView();
  const layerSection = useInView();

  return (
    <div className="min-h-screen bg-bg-base text-text-primary overflow-x-hidden">
      {/* Hero */}
      <header
        ref={heroSection.ref}
        className={`border-b border-border-subtle transition-all duration-700 ${heroSection.inView ? "animate-fade-up" : "opacity-0"}`}
      >
        <div className="max-w-5xl mx-auto px-6 py-16">
          <div className="flex items-baseline gap-3 mb-6">
            <span className="text-accent-cyan font-bold text-3xl tracking-[0.3em]">TALOS</span>
            <span className="text-text-secondary text-xs tracking-wider">PROTOCOL</span>
          </div>
          <h1 className="text-xl lg:text-2xl text-text-primary leading-relaxed max-w-xl">
            Pre-trade
            <span className="text-accent-cyan"> claim verification</span> and
            <span className="text-accent-cyan"> fund protection</span> layer for autonomous AI agents
          </h1>
          <p className="text-text-secondary text-sm mt-4 max-w-lg leading-relaxed">
            Agents must prove their claims before executing trades.
            If verification fails, the transaction never happens — funds stay safe.
          </p>
          <div className="flex items-center gap-6 mt-8">
            <Link
              href="/demo"
              className="px-6 py-2.5 bg-accent-cyan text-bg-base font-bold text-xs tracking-wider rounded-sm hover:shadow-[0_0_20px_rgba(57,208,216,0.3)] transition-all duration-300"
            >
              LIVE DEMO
            </Link>
            <span className="text-text-secondary text-[10px] tracking-wide">
              Monad Testnet | Chainlink Oracle | Real Contracts
            </span>
          </div>
        </div>
      </header>

      {/* Threats */}
      <section
        ref={threatSection.ref}
        className="max-w-5xl mx-auto px-6 py-16"
      >
        <h2 className={`text-sm font-bold text-text-secondary tracking-wider mb-8 transition-all duration-700 ${threatSection.inView ? "animate-fade-up" : "opacity-0"}`}>
          5 AGENT THREATS AND HOW TALOS SOLVES THEM
        </h2>

        <div className="space-y-2">
          {threats.map((t, i) => (
            <div
              key={i}
              className={`grid grid-cols-12 gap-4 items-center p-4 border border-border-subtle rounded-sm bg-bg-panel hover:border-accent-cyan/30 transition-all duration-500 ${threatSection.inView ? "animate-fade-up" : "opacity-0"}`}
              style={{ animationDelay: `${i * 100}ms` }}
            >
              <div className="col-span-1 text-center">
                <span className="text-text-secondary text-[10px]">0{i + 1}</span>
              </div>
              <div className="col-span-5">
                <p className="text-xs text-text-primary font-bold">{t.title}</p>
                <p className="text-[10px] text-text-secondary mt-0.5">{t.problem}</p>
              </div>
              <div className="col-span-1 text-center">
                <span className="text-accent-cyan/40">→</span>
              </div>
              <div className="col-span-5">
                <p className="text-[11px] text-accent-green">{t.solution}</p>
              </div>
            </div>
          ))}
        </div>
      </section>

      {/* Animated Flow */}
      <section
        ref={flowSection.ref}
        className={`max-w-5xl mx-auto px-6 py-16 border-t border-border-subtle transition-all duration-700 ${flowSection.inView ? "animate-fade-up" : "opacity-0"}`}
      >
        <h2 className="text-sm font-bold text-text-secondary tracking-wider mb-2">
          HOW IT WORKS
        </h2>
        <p className="text-text-secondary text-[11px] mb-10">
          Same user, same escrow — different agent behavior, different outcome
        </p>

        <AnimatedFlow />
      </section>

      {/* 3 Layers */}
      <section
        ref={layerSection.ref}
        className={`max-w-5xl mx-auto px-6 py-16 border-t border-border-subtle transition-all duration-700 ${layerSection.inView ? "animate-fade-up" : "opacity-0"}`}
      >
        <h2 className="text-sm font-bold text-text-secondary tracking-wider mb-8">
          3-LAYER VERIFICATION
        </h2>

        <div className="grid grid-cols-3 gap-px bg-border-subtle rounded-sm overflow-hidden">
          {[
            { num: "01", title: "HASH", desc: "Commit lock — claim cannot be altered" },
            { num: "02", title: "ORACLE", desc: "Chainlink price comparison" },
            { num: "03", title: "POLICY", desc: "Limits, drawdown, slippage checks" },
          ].map((layer) => (
            <div key={layer.num} className="bg-bg-panel p-5 text-center animate-shimmer">
              <span className="text-accent-cyan/50 text-[10px]">{layer.num}</span>
              <p className="text-xs font-bold text-text-primary mt-1">{layer.title}</p>
              <p className="text-[10px] text-text-secondary mt-1">{layer.desc}</p>
            </div>
          ))}
        </div>
      </section>

      {/* CTA */}
      <section className="max-w-5xl mx-auto px-6 py-16 border-t border-border-subtle text-center">
        <p className="text-text-secondary text-xs mb-5">
          4 scenarios — 1 click — live testnet
        </p>
        <Link
          href="/demo"
          className="inline-block px-10 py-3 bg-accent-cyan text-bg-base font-bold text-xs tracking-wider rounded-sm hover:shadow-[0_0_24px_rgba(57,208,216,0.4)] transition-all duration-300"
        >
          OPEN DEMO
        </Link>
      </section>

      {/* Footer */}
      <footer className="border-t border-border-subtle py-5 text-center text-[10px] text-text-secondary tracking-wide">
        TALOS PROTOCOL — Canakkale Monad Blitz Hackathon 2026
      </footer>
    </div>
  );
}
