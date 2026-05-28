"use client";

import { useEffect, useState } from "react";
import { api } from "../lib/api";
import {
  Users,
  CreditCard,
  DollarSign,
  Unlock,
  RefreshCw,
  TrendingUp,
  Globe,
  Clock,
} from "lucide-react";

export default function DashboardPage() {
  const [metrics, setMetrics] = useState<any>({
    dau: 1240,
    subscribers: 156,
    revenue: 945.50,
    unlocks: 432,
  });
  const [recentActivity, setRecentActivity] = useState<any[]>([]);
  const [countries, setCountries] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [polling, setPolling] = useState(false);

  const fetchData = async () => {
    setPolling(true);
    try {
      const [m, act, count] = await Promise.all([
        api.getOverviewMetrics(),
        api.getRecentActivity(),
        api.getCountryActivity(),
      ]);

      setMetrics(m);
      setRecentActivity(act);
      setCountries(count);
    } catch (err) {
      console.error("Failed to poll dashboard metrics", err);
    } finally {
      setLoading(false);
      setPolling(false);
    }
  };

  useEffect(() => {
    fetchData();

    // Poll data every 5 seconds to provide "realtime/near realtime" monitoring
    const interval = setInterval(fetchData, 5000);
    return () => clearInterval(interval);
  }, []);

  if (loading) {
    return (
      <div className="flex h-64 items-center justify-center text-[#8b5cf6]">
        <RefreshCw className="h-8 w-8 animate-spin" />
      </div>
    );
  }

  return (
    <div className="space-y-8">
      {/* Page Header */}
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
        <div>
          <h2 className="text-3xl font-bold tracking-tight text-white">Dashboard</h2>
          <p className="text-sm text-[#94a3b8]">
            Real-time reading platform statistics
          </p>
        </div>
        <button
          onClick={fetchData}
          disabled={polling}
          className="flex items-center self-start px-4 py-2 text-xs font-semibold uppercase tracking-wider text-slate-300 hover:text-white bg-[#101426] border border-[#2d334a] rounded-lg transition-colors gap-2"
        >
          <RefreshCw className={`h-4 w-4 ${polling ? "animate-spin" : ""}`} />
          {polling ? "Syncing..." : "Sync Now"}
        </button>
      </div>

      {/* Metrics Cards Grid */}
      <div className="grid gap-6 sm:grid-cols-2 lg:grid-cols-4">
        {/* Card: DAU */}
        <div className="rounded-xl border border-[#2d334a] bg-[#101426] p-6 shadow-sm">
          <div className="flex items-center justify-between">
            <span className="text-sm font-medium text-[#94a3b8]">Daily Active Users</span>
            <div className="rounded-lg bg-blue-500/10 p-2 text-blue-400">
              <Users className="h-5 w-5" />
            </div>
          </div>
          <div className="mt-4">
            <h3 className="text-3xl font-semibold text-white">{metrics.dau}</h3>
            <p className="mt-1 text-xs text-[#94a3b8] flex items-center gap-1">
              <span className="text-emerald-400 font-semibold flex items-center gap-0.5">
                <TrendingUp className="h-3 w-3" /> +12%
              </span>{" "}
              vs yesterday
            </p>
          </div>
        </div>

        {/* Card: Subscribers */}
        <div className="rounded-xl border border-[#2d334a] bg-[#101426] p-6 shadow-sm">
          <div className="flex items-center justify-between">
            <span className="text-sm font-medium text-[#94a3b8]">Active Subscribers</span>
            <div className="rounded-lg bg-purple-500/10 p-2 text-purple-400">
              <CreditCard className="h-5 w-5" />
            </div>
          </div>
          <div className="mt-4">
            <h3 className="text-3xl font-semibold text-white">{metrics.subscribers}</h3>
            <p className="mt-1 text-xs text-[#94a3b8]">
              <span className="text-purple-400 font-semibold">MoonPass Plus</span> active plans
            </p>
          </div>
        </div>

        {/* Card: Revenue */}
        <div className="rounded-xl border border-[#2d334a] bg-[#101426] p-6 shadow-sm">
          <div className="flex items-center justify-between">
            <span className="text-sm font-medium text-[#94a3b8]">Revenue Today</span>
            <div className="rounded-lg bg-emerald-500/10 p-2 text-emerald-400">
              <DollarSign className="h-5 w-5" />
            </div>
          </div>
          <div className="mt-4">
            <h3 className="text-3xl font-semibold text-white">${metrics.revenue.toFixed(2)}</h3>
            <p className="mt-1 text-xs text-[#94a3b8]">
              Includes IAP Coin packs and subscription dues
            </p>
          </div>
        </div>

        {/* Card: Unlocks */}
        <div className="rounded-xl border border-[#2d334a] bg-[#101426] p-6 shadow-sm">
          <div className="flex items-center justify-between">
            <span className="text-sm font-medium text-[#94a3b8]">Episode Unlocks</span>
            <div className="rounded-lg bg-amber-500/10 p-2 text-amber-400">
              <Unlock className="h-5 w-5" />
            </div>
          </div>
          <div className="mt-4">
            <h3 className="text-3xl font-semibold text-white">{metrics.unlocks}</h3>
            <p className="mt-1 text-xs text-[#94a3b8]">
              Unlocked by Coin, Ads, and Passes
            </p>
          </div>
        </div>
      </div>

      {/* Realtime / Recent Activity Table */}
      <div className="rounded-xl border border-[#2d334a] bg-[#101426] p-6 shadow-md">
        <div className="flex items-center justify-between mb-6">
          <div className="flex items-center gap-2">
            <Clock className="h-5 w-5 text-[#8b5cf6] animate-pulse" />
            <h3 className="text-lg font-semibold text-white">Real-time Activity Log</h3>
          </div>
          <span className="flex items-center text-xs text-emerald-400 font-semibold uppercase tracking-wider bg-emerald-500/10 border border-emerald-500/20 px-2.5 py-1 rounded-full gap-1.5">
            <span className="h-2 w-2 rounded-full bg-emerald-500 animate-ping" />
            Live Polling
          </span>
        </div>

        <div className="overflow-x-auto">
          <table className="w-full text-left text-sm border-collapse">
            <thead>
              <tr className="border-b border-[#2d334a] text-[#94a3b8] font-semibold">
                <th className="pb-3 pr-4">Time</th>
                <th className="pb-3 pr-4">User</th>
                <th className="pb-3 pr-4">Country</th>
                <th className="pb-3 pr-4">Action</th>
                <th className="pb-3 pr-4">Story</th>
                <th className="pb-3 pr-4">Episode</th>
                <th className="pb-3">Subscription</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-[#2d334a]/40 text-slate-300">
              {recentActivity.map((act, index) => (
                <tr key={index} className="hover:bg-[#171b31]/30 transition-colors">
                  <td className="py-3.5 pr-4 font-mono text-xs text-[#94a3b8]">{act.time}</td>
                  <td className="py-3.5 pr-4 font-semibold text-slate-200">{act.user}</td>
                  <td className="py-3.5 pr-4 text-xs font-medium text-slate-400">{act.country}</td>
                  <td className="py-3.5 pr-4">
                    <span className={`inline-flex items-center rounded-md px-2 py-1 text-xs font-semibold ${
                      act.action === "Subscribed" ? "bg-emerald-500/10 text-emerald-400" :
                      act.action === "Unlocked by Ad" ? "bg-amber-500/10 text-amber-400" :
                      "bg-blue-500/10 text-blue-400"
                    }`}>
                      {act.action}
                    </span>
                  </td>
                  <td className="py-3.5 pr-4 text-slate-200 font-semibold">{act.story}</td>
                  <td className="py-3.5 pr-4 font-mono text-xs text-[#94a3b8]">{act.episode}</td>
                  <td className="py-3.5">
                    <span className="text-xs font-medium text-[#8b5cf6]">{act.sub}</span>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>

      <div className="grid gap-6 md:grid-cols-2">
        {/* Country Breakdown */}
        <div className="rounded-xl border border-[#2d334a] bg-[#101426] p-6 shadow-md">
          <div className="flex items-center justify-between mb-6">
            <div className="flex items-center gap-2">
              <Globe className="h-5 w-5 text-[#8b5cf6]" />
              <h3 className="text-lg font-semibold text-white">Geographic Traffic</h3>
            </div>
          </div>

          <div className="overflow-x-auto">
            <table className="w-full text-left text-sm border-collapse">
              <thead>
                <tr className="border-b border-[#2d334a] text-[#94a3b8] font-semibold">
                  <th className="pb-3 pr-4">Country</th>
                  <th className="pb-3 pr-4 text-right">Active Readers</th>
                  <th className="pb-3 pr-4 text-right">Subscribers</th>
                  <th className="pb-3 text-right">Attributed Rev</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-[#2d334a]/40 text-slate-300">
                {countries.map((c, index) => (
                  <tr key={index} className="hover:bg-[#171b31]/30 transition-colors">
                    <td className="py-3.5 pr-4 font-semibold text-slate-200">{c.country}</td>
                    <td className="py-3.5 pr-4 text-right font-mono">{c.active_users}</td>
                    <td className="py-3.5 pr-4 text-right font-mono text-purple-400">{c.subscribers}</td>
                    <td className="py-3.5 text-right font-mono text-emerald-400">${c.revenue}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>

        {/* New vs Returning Users Graphic */}
        <div className="rounded-xl border border-[#2d334a] bg-[#101426] p-6 shadow-md flex flex-col">
          <div className="mb-6">
            <h3 className="text-lg font-semibold text-white">Audience Segments</h3>
            <p className="text-xs text-[#94a3b8]">New vs. Returning Readers ratio</p>
          </div>

          <div className="flex-1 flex flex-col justify-center items-center gap-6 py-6">
            {/* Custom Responsive SVG Donut Chart */}
            <div className="relative h-44 w-44">
              <svg className="w-full h-full transform -rotate-90" viewBox="0 0 36 36">
                {/* Background Ring */}
                <circle cx="18" cy="18" r="15.915" fill="none" stroke="#171b31" strokeWidth="3" />
                {/* Segment: New Users (35%) */}
                <circle cx="18" cy="18" r="15.915" fill="none" stroke="#8b5cf6" strokeWidth="3" strokeDasharray="35 65" />
                {/* Segment: Returning Users (65%) */}
                <circle cx="18" cy="18" r="15.915" fill="none" stroke="#a855f7" strokeWidth="3" strokeDasharray="65 35" strokeDashoffset="-35" />
              </svg>
              {/* Inner Label */}
              <div className="absolute inset-0 flex flex-col items-center justify-center">
                <span className="text-2xl font-bold text-white">65%</span>
                <span className="text-[10px] text-[#94a3b8] uppercase tracking-wider">Returning</span>
              </div>
            </div>

            {/* Labels */}
            <div className="flex gap-6 justify-center">
              <div className="flex items-center gap-2">
                <span className="h-3 w-3 rounded-full bg-[#8b5cf6]" />
                <div>
                  <p className="text-xs text-[#94a3b8]">New Users</p>
                  <p className="text-sm font-bold text-white">35%</p>
                </div>
              </div>
              <div className="flex items-center gap-2">
                <span className="h-3 w-3 rounded-full bg-[#a855f7]" />
                <div>
                  <p className="text-xs text-[#94a3b8]">Returning Users</p>
                  <p className="text-sm font-bold text-white">65%</p>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
