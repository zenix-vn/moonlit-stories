"use client";

import { useEffect, useState } from "react";
import { api } from "../../lib/api";
import { Send, History, Calendar, Bell, Plus, Compass } from "lucide-react";

export default function NotificationsPage() {
  const [campaigns, setCampaigns] = useState<any[]>([]);
  const [name, setName] = useState("");
  const [title, setTitle] = useState("");
  const [body, setBody] = useState("");
  const [deepLink, setDeepLink] = useState("");
  const [loading, setLoading] = useState(true);
  const [sending, setSending] = useState(false);
  const [error, setError] = useState("");
  const [success, setSuccess] = useState("");

  const loadData = async () => {
    try {
      const data = await api.listCampaigns();
      setCampaigns(data);
    } catch (err: any) {
      setError(err.message || "Failed to load push campaigns log");
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadData();
  }, []);

  const handleSendCampaign = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!name || !title || !body) {
      setError("Please fill out all mandatory fields.");
      return;
    }

    setSending(true);
    setError("");
    setSuccess("");

    try {
      const payload: any = {
        name,
        title,
        body,
      };
      if (deepLink.trim() !== "") {
        payload.deep_link = deepLink.trim();
      }

      await api.sendPushCampaign(payload);
      setSuccess("Push campaign dispatched to all active users!");
      
      // Clear fields
      setName("");
      setTitle("");
      setBody("");
      setDeepLink("");
      
      // Refresh list
      loadData();
    } catch (err: any) {
      setError(err.message || "Failed to dispatch campaign");
    } finally {
      setSending(false);
    }
  };

  if (loading) {
    return (
      <div className="flex h-64 items-center justify-center text-[#8b5cf6]">
        <Bell className="h-8 w-8 animate-spin" />
      </div>
    );
  }

  return (
    <div className="space-y-8">
      <div>
        <h2 className="text-3xl font-bold tracking-tight text-white">Push Campaigns</h2>
        <p className="text-sm text-[#94a3b8]">
          Send simulated push notifications and in-app updates to all registered device tokens
        </p>
      </div>

      {error && (
        <div className="rounded-lg bg-red-950/50 border border-red-500/30 p-4 text-sm text-red-400">
          {error}
        </div>
      )}

      {success && (
        <div className="rounded-lg bg-emerald-950/50 border border-emerald-500/30 p-4 text-sm text-emerald-400">
          {success}
        </div>
      )}

      <div className="grid gap-8 lg:grid-cols-3">
        {/* Dispatch Form */}
        <div className="lg:col-span-1 rounded-xl border border-[#2d334a] bg-[#101426] p-6 shadow-md h-fit">
          <h3 className="text-lg font-semibold text-white mb-6 flex items-center gap-2">
            <Plus className="h-5 w-5 text-[#8b5cf6]" />
            New Campaign
          </h3>

          <form onSubmit={handleSendCampaign} className="space-y-4 text-sm">
            <div>
              <label className="block text-xs font-semibold uppercase tracking-wider text-[#94a3b8] mb-1.5">
                Campaign Name (Internal)
              </label>
              <input
                type="text"
                placeholder="E.g. Daily Bonus Coins Gift"
                value={name}
                onChange={(e) => setName(e.target.value)}
                className="block w-full rounded-lg border border-[#2d334a] bg-[#171b31] py-2 px-3 text-white focus:border-[#8b5cf6] focus:outline-none"
              />
            </div>

            <div>
              <label className="block text-xs font-semibold uppercase tracking-wider text-[#94a3b8] mb-1.5">
                Push Title (Shown to User)
              </label>
              <input
                type="text"
                placeholder="E.g. You received a gift! 🎁"
                value={title}
                onChange={(e) => setTitle(e.target.value)}
                className="block w-full rounded-lg border border-[#2d334a] bg-[#171b31] py-2 px-3 text-white focus:border-[#8b5cf6] focus:outline-none"
              />
            </div>

            <div>
              <label className="block text-xs font-semibold uppercase tracking-wider text-[#94a3b8] mb-1.5">
                Push Body Text
              </label>
              <textarea
                rows={3}
                placeholder="E.g. We added 100 free coins to your wallet. Tap to start reading the latest hot releases tonight."
                value={body}
                onChange={(e) => setBody(e.target.value)}
                className="block w-full rounded-lg border border-[#2d334a] bg-[#171b31] py-2 px-3 text-white focus:border-[#8b5cf6] focus:outline-none"
              />
            </div>

            <div>
              <label className="block text-xs font-semibold uppercase tracking-wider text-[#94a3b8] mb-1.5">
                Deep Link URL (Optional)
              </label>
              <input
                type="text"
                placeholder="E.g. moonlit://story/reborn-as-the-villain-queen"
                value={deepLink}
                onChange={(e) => setDeepLink(e.target.value)}
                className="block w-full rounded-lg border border-[#2d334a] bg-[#171b31] py-2 px-3 font-mono text-white text-xs"
              />
            </div>

            <button
              type="submit"
              disabled={sending}
              className="mt-6 flex w-full justify-center items-center rounded-lg bg-[#8b5cf6] hover:bg-[#7c3aed] py-2.5 px-4 font-semibold text-white transition-colors gap-2"
            >
              <Send className="h-4 w-4" />
              {sending ? "Dispatching..." : "Send Campaign"}
            </button>
          </form>
        </div>

        {/* Audit Log / History */}
        <div className="lg:col-span-2 rounded-xl border border-[#2d334a] bg-[#101426] p-6 shadow-md">
          <h3 className="text-lg font-semibold text-white mb-6 flex items-center gap-2">
            <History className="h-5 w-5 text-[#8b5cf6]" />
            Campaign Logs
          </h3>

          <div className="space-y-4">
            {campaigns.map((camp) => (
              <div
                key={camp.id}
                className="p-4 rounded-xl border border-[#2d334a]/60 bg-[#171b31]/40 space-y-3"
              >
                <div className="flex items-start justify-between">
                  <div>
                    <h4 className="font-bold text-white text-sm">{camp.name}</h4>
                    <p className="text-xs text-[#94a3b8] font-mono mt-0.5">{camp.id}</p>
                  </div>
                  <span className="inline-flex items-center gap-1.5 rounded-full bg-purple-500/10 border border-purple-500/20 px-2.5 py-0.5 text-xs font-semibold text-purple-400">
                    Dispatched
                  </span>
                </div>

                <div className="bg-[#101426]/60 p-3 rounded-lg border border-[#2d334a]/30">
                  <p className="text-xs font-bold text-slate-200">"{camp.title}"</p>
                  <p className="text-xs text-[#94a3b8] mt-1">{camp.body}</p>
                  {camp.deep_link && (
                    <div className="flex items-center gap-1 mt-2 text-[10px] font-mono text-purple-400">
                      <Compass className="h-3 w-3" />
                      {camp.deep_link}
                    </div>
                  )}
                </div>

                <div className="flex items-center gap-1 text-[10px] text-[#64748b]">
                  <Calendar className="h-3.5 w-3.5" />
                  Sent: {new Date(camp.created_at).toLocaleString()}
                </div>
              </div>
            ))}

            {campaigns.length === 0 && (
              <div className="text-center py-12 text-[#94a3b8] text-xs">
                No campaign logs recorded yet. Create one to begin.
              </div>
            )}
          </div>
        </div>
      </div>
    </div>
  );
}
