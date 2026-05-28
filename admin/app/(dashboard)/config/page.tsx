"use client";

import { useEffect, useState } from "react";
import { api } from "../../lib/api";
import { Settings, Save, ToggleLeft, ToggleRight, Info, AlertTriangle } from "lucide-react";

export default function ConfigPage() {
  const [config, setConfig] = useState<any>({
    free_episode_count: 3,
    default_episode_coin_price: 20,
    maintenance_mode: false,
    min_supported_version: "1.0.0",
  });
  const [flags, setFlags] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState("");
  const [success, setSuccess] = useState("");

  const loadData = async () => {
    try {
      const [configData, flagsData] = await Promise.all([
        api.getAppConfig(),
        api.listFeatureFlags(),
      ]);
      setConfig(configData);
      setFlags(flagsData);
    } catch (err: any) {
      setError(err.message || "Failed to load configuration data");
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadData();
  }, []);

  const handleUpdateConfig = async (e: React.FormEvent) => {
    e.preventDefault();
    setSaving(true);
    setError("");
    setSuccess("");

    try {
      await api.updateAppConfig("system_config", config);
      setSuccess("Global configurations updated successfully!");
    } catch (err: any) {
      setError(err.message || "Failed to update configs");
    } finally {
      setSaving(false);
    }
  };

  const handleToggleFlag = async (key: string, currentStatus: boolean) => {
    try {
      const newStatus = !currentStatus;
      await api.updateFeatureFlag(key, newStatus);
      // Optimistic state update in UI
      setFlags((prev) =>
        prev.map((f) => (f.key === key ? { ...f, enabled: newStatus } : f))
      );
    } catch (err: any) {
      setError(err.message || "Failed to update feature flag");
    }
  };

  if (loading) {
    return (
      <div className="flex h-64 items-center justify-center text-[#8b5cf6]">
        <Settings className="h-8 w-8 animate-spin" />
      </div>
    );
  }

  return (
    <div className="space-y-8">
      <div>
        <h2 className="text-3xl font-bold tracking-tight text-white">App Configurations</h2>
        <p className="text-sm text-[#94a3b8]">
          Remote control application behaviors, standard coin prices, and toggle feature flags
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

      <div className="grid gap-8 md:grid-cols-2">
        {/* Global Remote Settings */}
        <div className="rounded-xl border border-[#2d334a] bg-[#101426] p-6 shadow-md h-fit">
          <h3 className="text-lg font-semibold text-white mb-6">Global Variables</h3>

          <form onSubmit={handleUpdateConfig} className="space-y-4 text-sm">
            <div>
              <label className="block text-xs font-semibold uppercase tracking-wider text-[#94a3b8] mb-2">
                Free Episodes Count
              </label>
              <input
                type="number"
                min="0"
                value={config.free_episode_count}
                onChange={(e) =>
                  setConfig({ ...config, free_episode_count: Number(e.target.value) })
                }
                className="block w-full rounded-lg border border-[#2d334a] bg-[#171b31] py-2 px-3 text-white focus:border-[#8b5cf6] focus:outline-none"
              />
              <p className="text-[11px] text-[#94a3b8] mt-1.5">
                Standard number of free chapters granted to guests on newly created stories
              </p>
            </div>

            <div>
              <label className="block text-xs font-semibold uppercase tracking-wider text-[#94a3b8] mb-2">
                Default Episode Coin Price
              </label>
              <input
                type="number"
                min="0"
                value={config.default_episode_coin_price}
                onChange={(e) =>
                  setConfig({ ...config, default_episode_coin_price: Number(e.target.value) })
                }
                className="block w-full rounded-lg border border-[#2d334a] bg-[#171b31] py-2 px-3 text-white focus:border-[#8b5cf6] focus:outline-none"
              />
            </div>

            <div>
              <label className="block text-xs font-semibold uppercase tracking-wider text-[#94a3b8] mb-2">
                Minimum App Build Version
              </label>
              <input
                type="text"
                value={config.min_supported_version}
                onChange={(e) =>
                  setConfig({ ...config, min_supported_version: e.target.value })
                }
                className="block w-full rounded-lg border border-[#2d334a] bg-[#171b31] py-2 px-3 font-mono text-white text-xs"
              />
              <p className="text-[11px] text-[#94a3b8] mt-1.5">
                Force update will trigger on user devices below this build version
              </p>
            </div>

            <div className="pt-2">
              <label className="flex items-center gap-3 text-slate-300 select-none">
                <input
                  type="checkbox"
                  checked={config.maintenance_mode}
                  onChange={(e) =>
                    setConfig({ ...config, maintenance_mode: e.target.checked })
                  }
                  className="rounded border-[#2d334a] bg-[#171b31]"
                />
                <span className="flex items-center text-sm font-medium text-slate-200 gap-1.5">
                  Enable Maintenance Mode
                  {config.maintenance_mode && (
                    <AlertTriangle className="h-4 w-4 text-amber-400 animate-bounce" />
                  )}
                </span>
              </label>
            </div>

            <button
              type="submit"
              disabled={saving}
              className="mt-6 flex w-full justify-center items-center rounded-lg bg-[#8b5cf6] hover:bg-[#7c3aed] py-2.5 px-4 font-semibold text-white transition-colors gap-2"
            >
              <Save className="h-4 w-4" />
              {saving ? "Saving Changes..." : "Save Settings"}
            </button>
          </form>
        </div>

        {/* Feature Flags */}
        <div className="rounded-xl border border-[#2d334a] bg-[#101426] p-6 shadow-md h-fit">
          <div className="mb-6">
            <h3 className="text-lg font-semibold text-white">Feature Rollouts</h3>
            <p className="text-xs text-[#94a3b8]">Selectively enable dynamic modules for testing</p>
          </div>

          <div className="space-y-4">
            {flags.map((flag) => (
              <div
                key={flag.key}
                className="flex items-center justify-between p-4 rounded-xl border border-[#2d334a]/60 bg-[#171b31]/40"
              >
                <div>
                  <h4 className="font-bold text-slate-100 text-sm font-mono">{flag.key}</h4>
                  <p className="text-xs text-[#94a3b8] mt-1">{flag.description}</p>
                  {flag.rollout_percentage !== undefined && (
                    <span className="inline-block mt-2 text-[10px] uppercase font-bold text-purple-400 bg-purple-500/10 border border-purple-500/20 px-2 py-0.5 rounded-full">
                      Rollout {flag.rollout_percentage}%
                    </span>
                  )}
                </div>

                <button
                  onClick={() => handleToggleFlag(flag.key, flag.enabled)}
                  className="focus:outline-none transition-colors text-slate-400 hover:text-white"
                >
                  {flag.enabled ? (
                    <ToggleRight className="h-10 w-10 text-purple-500" />
                  ) : (
                    <ToggleLeft className="h-10 w-10 text-slate-600" />
                  )}
                </button>
              </div>
            ))}

            {flags.length === 0 && (
              <div className="text-center py-6 text-xs text-[#94a3b8] flex items-center justify-center gap-1.5">
                <Info className="h-4 w-4" />
                No active feature flags registered.
              </div>
            )}
          </div>
        </div>
      </div>
    </div>
  );
}
