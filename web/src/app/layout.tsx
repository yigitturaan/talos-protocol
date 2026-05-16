import type { Metadata } from "next";
import { JetBrains_Mono } from "next/font/google";
import "./globals.css";

const jetbrainsMono = JetBrains_Mono({
  subsets: ["latin"],
  variable: "--font-mono",
});

export const metadata: Metadata = {
  title: "TALOS Terminal",
  description:
    "Pre-execution claim verification for AI trading agents on Monad",
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en" className="dark">
      <body
        className={`${jetbrainsMono.variable} bg-bg-base text-text-primary font-mono antialiased`}
      >
        {children}
      </body>
    </html>
  );
}
