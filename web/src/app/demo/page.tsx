"use client";

import { Providers } from "../providers";
import { TopBar } from "@/components/layout/TopBar";
import { StatusBar } from "@/components/layout/StatusBar";
import { DemoPanel } from "@/components/DemoPanel";
import { VerificationFeed } from "@/components/VerificationFeed";
import { ReputationLeaderboard } from "@/components/ReputationLeaderboard";

export default function DemoPage() {
  return (
    <Providers>
      <div className="flex flex-col h-screen">
        <TopBar />

        <main className="flex-1 grid grid-cols-1 lg:grid-cols-12 gap-px bg-border-subtle overflow-hidden">
          <div className="lg:col-span-5 bg-bg-base overflow-y-auto p-2 space-y-2">
            <DemoPanel />
          </div>

          <div className="lg:col-span-4 bg-bg-base overflow-y-auto p-2">
            <VerificationFeed />
          </div>

          <div className="lg:col-span-3 bg-bg-base overflow-y-auto p-2">
            <ReputationLeaderboard />
          </div>
        </main>

        <StatusBar />
      </div>
    </Providers>
  );
}
