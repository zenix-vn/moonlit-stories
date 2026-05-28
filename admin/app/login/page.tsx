"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { api } from "../lib/api";
import { Moon, Shield, Lock, Mail, Loader2 } from "lucide-react";

export default function LoginPage() {
  const router = useRouter();
  const [email, setEmail] = useState("admin@moonlitstories.com");
  const [password, setPassword] = useState("admin123");
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError("");
    setLoading(true);

    try {
      await api.login(email, password);
      router.push("/");
    } catch (err: any) {
      setError(err.message || "Invalid credentials. Please try again.");
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="flex min-h-screen flex-col items-center justify-center bg-[#050816] px-4 py-12 sm:px-6 lg:px-8">
      {/* Decorative Glows */}
      <div className="absolute top-1/4 left-1/4 -z-10 h-72 w-72 rounded-full bg-purple-900/20 blur-3xl" />
      <div className="absolute bottom-1/4 right-1/4 -z-10 h-72 w-72 rounded-full bg-blue-900/10 blur-3xl" />

      <div className="w-full max-w-md space-y-8 rounded-2xl border border-[#2d334a] bg-[#101426] p-8 shadow-2xl backdrop-blur-md">
        <div className="text-center">
          <div className="mx-auto flex h-14 w-14 items-center justify-center rounded-full bg-[#171b31] text-[#8b5cf6] border border-purple-500/20">
            <Moon className="h-8 w-8 animate-pulse" />
          </div>
          <h2 className="mt-6 text-3xl font-bold tracking-tight text-white">
            Moonlit Stories
          </h2>
          <p className="mt-2 text-sm text-[#94a3b8]">
            Admin Control Center
          </p>
        </div>

        {error && (
          <div className="rounded-lg bg-red-950/50 border border-red-500/30 p-4 text-sm text-red-400">
            {error}
          </div>
        )}

        <form className="mt-8 space-y-6" onSubmit={handleSubmit}>
          <div className="space-y-4 rounded-md">
            <div>
              <label className="block text-xs font-semibold uppercase tracking-wider text-[#94a3b8] mb-2">
                Email Address
              </label>
              <div className="relative">
                <span className="absolute inset-y-0 left-0 flex items-center pl-3 text-[#94a3b8]">
                  <Mail className="h-5 w-5" />
                </span>
                <input
                  type="email"
                  required
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                  className="block w-full rounded-lg border border-[#2d334a] bg-[#171b31] py-3 pl-10 pr-3 text-sm text-white placeholder-slate-500 focus:border-[#8b5cf6] focus:outline-none focus:ring-1 focus:ring-[#8b5cf6]"
                  placeholder="admin@moonlitstories.com"
                />
              </div>
            </div>

            <div>
              <label className="block text-xs font-semibold uppercase tracking-wider text-[#94a3b8] mb-2">
                Password
              </label>
              <div className="relative">
                <span className="absolute inset-y-0 left-0 flex items-center pl-3 text-[#94a3b8]">
                  <Lock className="h-5 w-5" />
                </span>
                <input
                  type="password"
                  required
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  className="block w-full rounded-lg border border-[#2d334a] bg-[#171b31] py-3 pl-10 pr-3 text-sm text-white placeholder-slate-500 focus:border-[#8b5cf6] focus:outline-none focus:ring-1 focus:ring-[#8b5cf6]"
                  placeholder="••••••••"
                />
              </div>
            </div>
          </div>

          <div>
            <button
              type="submit"
              disabled={loading}
              className="group relative flex w-full justify-center rounded-lg bg-gradient-to-r from-[#8b5cf6] to-[#a855f7] py-3 px-4 text-sm font-semibold text-white shadow-md hover:from-[#7c3aed] hover:to-[#9333ea] focus:outline-none focus:ring-2 focus:ring-[#8b5cf6] focus:ring-offset-2 focus:ring-offset-[#050816] disabled:opacity-50 disabled:cursor-not-allowed transition-all duration-200"
            >
              {loading ? (
                <Loader2 className="mr-2 h-5 w-5 animate-spin" />
              ) : (
                <Shield className="mr-2 h-5 w-5" />
              )}
              {loading ? "Verifying..." : "Authorize Access"}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}
