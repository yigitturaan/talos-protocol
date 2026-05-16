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
    <div className="grid grid-cols-1 md:grid-cols-2 gap-16 max-w-4xl mx-auto py-8">
      {/* PASS FLOW */}
      <div className="flex flex-col items-center">
        <p className="text-center text-sm text-accent-green font-bold mb-8 tracking-wider uppercase drop-shadow-sm">
          Verification Passed
        </p>
        <div className="relative h-80 w-full max-w-[240px]">
          {/* Main Track Line */}
          <div className="absolute left-1/2 top-0 bottom-0 w-[3px] bg-border-subtle/50 -translate-x-1/2 rounded-full" />
          
          {/* Labels */}
          <div className="absolute w-full top-[0%] flex justify-between items-center -mt-3">
             <span className="text-sm font-semibold text-accent-purple w-1/2 text-right pr-6 drop-shadow-sm">User</span>
             <span className="text-xs text-text-secondary w-1/2 pl-6">Initiates</span>
          </div>
          <div className="absolute w-full top-[33%] flex justify-between items-center -mt-3">
             <span className="text-sm font-semibold text-text-primary w-1/2 text-right pr-6">Escrow</span>
             <span className="text-xs text-text-secondary w-1/2 pl-6">Locked</span>
          </div>
          <div className="absolute w-full top-[66%] flex justify-between items-center -mt-3">
             <span className="text-sm font-semibold text-text-primary w-1/2 text-right pr-6">Talos</span>
             <span className="text-xs text-accent-green w-1/2 pl-6">Validates</span>
          </div>
          <div className="absolute w-full top-[100%] flex justify-between items-center -mt-3">
             <span className="text-sm font-semibold text-text-primary w-1/2 text-right pr-6">Target</span>
             <span className="text-xs text-accent-green w-1/2 pl-6 font-medium">Executed</span>
          </div>

          {/* Node Dots */}
          <div className="absolute left-1/2 top-[0%] w-3 h-3 rounded-full bg-accent-purple -translate-x-1/2 -mt-1.5 ring-4 ring-bg-base z-10" />
          <div className="absolute left-1/2 top-[33%] w-3 h-3 rounded-full bg-border-subtle -translate-x-1/2 -mt-1.5 ring-4 ring-bg-base z-10" />
          <div className="absolute left-1/2 top-[66%] w-3 h-3 rounded-full bg-border-subtle -translate-x-1/2 -mt-1.5 ring-4 ring-bg-base z-10" />
          <div className="absolute left-1/2 top-[100%] w-3 h-3 rounded-full bg-border-subtle -translate-x-1/2 -mt-1.5 ring-4 ring-bg-base z-10" />

          {/* Animated Dot */}
          <div className="flow-dot-pass absolute left-1/2 w-4 h-4 rounded-full -translate-x-1/2 -mt-2 shadow-[0_0_16px_currentColor] z-20" />
        </div>
      </div>

      {/* FAIL FLOW */}
      <div className="flex flex-col items-center">
        <p className="text-center text-sm text-accent-red font-bold mb-8 tracking-wider uppercase drop-shadow-sm">
          Verification Failed
        </p>
        <div className="relative h-80 w-full max-w-[240px]">
          {/* Main Track Line */}
          <div className="absolute left-1/2 top-0 bottom-[34%] w-[3px] bg-border-subtle/50 -translate-x-1/2 rounded-full" />
          {/* Faded track to target since it never reaches it */}
          <div className="absolute left-1/2 top-[66%] bottom-0 w-[3px] bg-border-subtle/20 -translate-x-1/2 rounded-full" />
          
          {/* Labels */}
          <div className="absolute w-full top-[0%] flex justify-between items-center -mt-3">
             <span className="text-xs text-accent-red w-1/2 text-right pr-6 font-medium">Refunded</span>
             <span className="text-sm font-semibold text-accent-purple w-1/2 pl-6 drop-shadow-sm">User</span>
          </div>
          <div className="absolute w-full top-[33%] flex justify-between items-center -mt-3">
             <span className="text-xs text-text-secondary w-1/2 text-right pr-6">Locked</span>
             <span className="text-sm font-semibold text-text-primary w-1/2 pl-6">Escrow</span>
          </div>
          <div className="absolute w-full top-[66%] flex justify-between items-center -mt-3">
             <span className="text-xs text-accent-red w-1/2 text-right pr-6 font-medium">Rejects</span>
             <span className="text-sm font-semibold text-text-primary w-1/2 pl-6">Talos</span>
          </div>
          <div className="absolute w-full top-[100%] flex justify-between items-center -mt-3 opacity-40">
             <span className="text-xs text-text-secondary w-1/2 text-right pr-6">Blocked</span>
             <span className="text-sm font-semibold text-text-primary w-1/2 pl-6">Target</span>
          </div>

          {/* Node Dots */}
          <div className="absolute left-1/2 top-[0%] w-3 h-3 rounded-full bg-accent-purple -translate-x-1/2 -mt-1.5 ring-4 ring-bg-base z-10" />
          <div className="absolute left-1/2 top-[33%] w-3 h-3 rounded-full bg-border-subtle -translate-x-1/2 -mt-1.5 ring-4 ring-bg-base z-10" />
          <div className="absolute left-1/2 top-[66%] w-3 h-3 rounded-full bg-border-subtle -translate-x-1/2 -mt-1.5 ring-4 ring-bg-base z-10" />
          <div className="absolute left-1/2 top-[100%] w-3 h-3 rounded-full bg-border-subtle/20 -translate-x-1/2 -mt-1.5 ring-4 ring-bg-base z-10" />

          {/* Animated Dot */}
          <div className="flow-dot-fail absolute left-1/2 w-4 h-4 rounded-full -translate-x-1/2 -mt-2 shadow-[0_0_16px_currentColor] z-20" />
        </div>
      </div>
    </div>
  );
}

const threats = [
  {
    title: "Data Hallucination",
    solution: "Live comparison against Chainlink oracle feed",
  },
  {
    title: "Post-Commit Tampering",
    solution: "Cryptographic hash lock — tampering detected instantly",
  },
  {
    title: "Overspending",
    solution: "Daily/weekly spending limits + max drawdown policy",
  },
  {
    title: "Slippage Manipulation",
    solution: "Market-price-based slippage guard enforcement",
  },
  {
    title: "Malicious Contracts",
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
          <div className="flex items-baseline gap-3 mb-8">
            <span className="text-accent-purple font-extrabold text-4xl tracking-widest drop-shadow-sm">TALOS</span>
            <span className="text-text-secondary/80 text-xs tracking-[0.2em] font-medium">PROTOCOL</span>
          </div>
          <h1 className="text-2xl lg:text-4xl text-text-primary leading-tight max-w-2xl font-semibold tracking-tight">
            Pre-trade
            <span className="text-accent-purple drop-shadow-sm"> claim verification</span> and
            <span className="text-accent-purple drop-shadow-sm"> fund protection</span> layer for autonomous AI agents.
          </h1>
          <p className="text-text-secondary text-sm mt-4 max-w-lg leading-relaxed">
            Agents must prove their claims before executing trades.
            If verification fails, the transaction never happens — funds stay safe.
          </p>
          <div className="flex items-center gap-6 mt-8">
            <Link
              href="/demo"
              className="px-8 py-3 bg-accent-purple text-white font-semibold text-sm tracking-wide rounded-full hover:shadow-[0_0_24px_rgba(131,110,249,0.4)] hover:-translate-y-0.5 transition-all duration-300"
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
          5 THREATS SOLVED
        </h2>

        <div className="flex flex-col gap-3">
          {threats.map((t, i) => (
            <div
              key={i}
              className={`group flex flex-col md:flex-row items-start md:items-center justify-between gap-4 p-5 border border-border-subtle/50 rounded-xl bg-bg-elevated/20 hover:bg-bg-elevated/40 hover:border-accent-purple/40 hover:-translate-y-0.5 hover:shadow-md transition-all duration-500 ${threatSection.inView ? "animate-fade-up" : "opacity-0"}`}
              style={{ animationDelay: `${i * 100}ms` }}
            >
              <div className="flex items-center gap-4 md:w-1/3">
                <span className="text-text-secondary/50 text-[10px] font-mono">0{i + 1}</span>
                <p className="text-sm text-text-primary font-bold group-hover:text-accent-purple transition-colors duration-300">{t.title}</p>
              </div>
              
              <div className="hidden md:block text-accent-purple/40 font-bold group-hover:text-accent-purple/80 transition-colors duration-300">→</div>
              
              <div className="md:w-1/2 flex md:justify-end">
                <p className="text-xs text-accent-green/90 font-medium text-left md:text-right">{t.solution}</p>
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
            <div key={layer.num} className="bg-bg-elevated/40 p-6 text-center animate-shimmer backdrop-blur-sm">
              <span className="text-accent-purple/60 text-[11px] font-semibold">{layer.num}</span>
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
          className="inline-block px-12 py-3.5 bg-accent-purple text-white font-semibold text-sm tracking-wide rounded-full hover:shadow-[0_0_30px_rgba(131,110,249,0.5)] hover:-translate-y-1 transition-all duration-300"
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
