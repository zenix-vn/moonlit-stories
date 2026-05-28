"use client";

import { useEffect, useState } from "react";
import { api } from "../../lib/api";
import { Image as ImageIcon, Plus, CheckCircle, EyeOff, Tag, Compass } from "lucide-react";

export default function BannersPage() {
  const [banners, setBanners] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");

  // New Banner Form State
  const [title, setTitle] = useState("");
  const [subtitle, setSubtitle] = useState("");
  const [imageURL, setImageURL] = useState("");
  const [deepLink, setDeepLink] = useState("");
  const [placement, setPlacement] = useState("home_top");
  const [priority, setPriority] = useState(0);
  const [active, setActive] = useState(true);
  const [creating, setCreating] = useState(false);

  const fetchBanners = async () => {
    try {
      const data = await api.listBanners();
      setBanners(data);
    } catch (err: any) {
      setError(err.message || "Failed to load banners");
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchBanners();
  }, []);

  const handleCreateBanner = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!title || !imageURL) return;
    setCreating(true);

    try {
      await api.createBanner({
        title,
        subtitle: subtitle || null,
        image_url: imageURL,
        deep_link: deepLink || null,
        placement,
        priority: Number(priority),
        active,
      });

      // Clear Form
      setTitle("");
      setSubtitle("");
      setImageURL("");
      setDeepLink("");
      setPriority(0);
      fetchBanners();
    } catch (err: any) {
      setError(err.message || "Failed to create banner");
    } finally {
      setCreating(false);
    }
  };

  if (loading) {
    return (
      <div className="flex h-64 items-center justify-center text-[#8b5cf6]">
        <ImageIcon className="h-8 w-8 animate-spin" />
      </div>
    );
  }

  return (
    <div className="space-y-8">
      <div>
        <h2 className="text-3xl font-bold tracking-tight text-white">Banner Placements CMS</h2>
        <p className="text-sm text-[#94a3b8]">
          Manage promotional cards, sales ads, and spotlight banners in the mobile reader
        </p>
      </div>

      {error && (
        <div className="rounded-lg bg-red-950/50 border border-red-500/30 p-4 text-sm text-red-400">
          {error}
        </div>
      )}

      <div className="grid gap-8 lg:grid-cols-3">
        {/* Banner placements list */}
        <div className="lg:col-span-2 space-y-4">
          <h3 className="text-lg font-semibold text-white">Active App Placements ({banners.length})</h3>

          <div className="grid gap-4 sm:grid-cols-2">
            {banners.map((b) => (
              <div
                key={b.id}
                className="flex flex-col rounded-xl border border-[#2d334a] bg-[#101426] overflow-hidden"
              >
                {/* Image header */}
                <div className="h-36 bg-[#171b31] relative overflow-hidden flex items-center justify-center">
                  {b.image_url ? (
                    <img
                      src={b.image_url}
                      alt={b.title}
                      className="w-full h-full object-cover opacity-75"
                    />
                  ) : (
                    <ImageIcon className="h-10 w-10 text-[#94a3b8]" />
                  )}
                  <div className="absolute top-3 right-3 flex gap-2">
                    <span className={`inline-flex items-center rounded-md px-2 py-0.5 text-xs font-semibold uppercase tracking-wider ${
                      b.active ? "bg-emerald-500/20 text-emerald-400 border border-emerald-500/30" : "bg-slate-500/20 text-slate-400"
                    }`}>
                      {b.active ? "Active" : "Inactive"}
                    </span>
                    <span className="inline-flex items-center rounded-md bg-purple-500/20 text-purple-400 border border-purple-500/30 px-2 py-0.5 text-xs font-semibold font-mono">
                      Pri {b.priority}
                    </span>
                  </div>
                </div>

                <div className="p-5 flex-1 flex flex-col justify-between">
                  <div>
                    <h4 className="font-bold text-white text-md line-clamp-1">{b.title}</h4>
                    {b.subtitle && (
                      <p className="text-xs text-[#94a3b8] mt-1 line-clamp-1">{b.subtitle}</p>
                    )}
                    <div className="mt-3 flex items-center gap-1 text-xs text-slate-400 font-mono">
                      <Compass className="h-3.5 w-3.5 text-[#8b5cf6]" />
                      <span>{b.placement}</span>
                    </div>
                  </div>

                  {b.deep_link && (
                    <div className="mt-4 pt-3 border-t border-[#2d334a]/40 text-xs text-[#94a3b8] truncate font-mono">
                      <span className="font-semibold text-slate-300">Action Link:</span> {b.deep_link}
                    </div>
                  )}
                </div>
              </div>
            ))}
          </div>
        </div>

        {/* Add Banner Form */}
        <div className="rounded-xl border border-[#2d334a] bg-[#101426] p-6 shadow-md h-fit">
          <h3 className="text-lg font-semibold text-white mb-6 flex items-center gap-2">
            <Plus className="h-5 w-5 text-[#8b5cf6]" />
            Add Promotion Banner
          </h3>

          <form onSubmit={handleCreateBanner} className="space-y-4 text-sm">
            <div>
              <label className="block text-xs font-semibold uppercase tracking-wider text-[#94a3b8] mb-2">
                Ad Title
              </label>
              <input
                type="text"
                required
                value={title}
                onChange={(e) => setTitle(e.target.value)}
                className="block w-full rounded-lg border border-[#2d334a] bg-[#171b31] py-2 px-3 text-white placeholder-slate-500 focus:border-[#8b5cf6] focus:outline-none"
                placeholder="e.g. MoonPass 20% Discount"
              />
            </div>

            <div>
              <label className="block text-xs font-semibold uppercase tracking-wider text-[#94a3b8] mb-2">
                Subtitle / Description
              </label>
              <input
                type="text"
                value={subtitle}
                onChange={(e) => setSubtitle(e.target.value)}
                className="block w-full rounded-lg border border-[#2d334a] bg-[#171b31] py-2 px-3 text-white placeholder-slate-500"
                placeholder="e.g. Unlock unlimited late-night horror"
              />
            </div>

            <div>
              <label className="block text-xs font-semibold uppercase tracking-wider text-[#94a3b8] mb-2">
                Banner Image URL
              </label>
              <input
                type="text"
                required
                value={imageURL}
                onChange={(e) => setImageURL(e.target.value)}
                className="block w-full rounded-lg border border-[#2d334a] bg-[#171b31] py-2 px-3 text-white placeholder-slate-500"
                placeholder="https://images.unsplash.com/photo-..."
              />
            </div>

            <div>
              <label className="block text-xs font-semibold uppercase tracking-wider text-[#94a3b8] mb-2">
                Action Deep Link / Route
              </label>
              <input
                type="text"
                value={deepLink}
                onChange={(e) => setDeepLink(e.target.value)}
                className="block w-full rounded-lg border border-[#2d334a] bg-[#171b31] py-2 px-3 text-white placeholder-slate-500"
                placeholder="e.g. moonlit://store/moonpass"
              />
            </div>

            <div className="grid grid-cols-2 gap-4">
              <div>
                <label className="block text-xs font-semibold uppercase tracking-wider text-[#94a3b8] mb-2">
                  Placement
                </label>
                <select
                  value={placement}
                  onChange={(e) => setPlacement(e.target.value)}
                  className="block w-full rounded-lg border border-[#2d334a] bg-[#171b31] py-2 px-3 text-white"
                >
                  <option value="home_top">Home Top</option>
                  <option value="home_mid">Home Mid</option>
                  <option value="discover_top">Discover Top</option>
                  <option value="reader_end">Reader End</option>
                </select>
              </div>
              <div>
                <label className="block text-xs font-semibold uppercase tracking-wider text-[#94a3b8] mb-2">
                  Priority (Order)
                </label>
                <input
                  type="number"
                  value={priority}
                  onChange={(e) => setPriority(Number(e.target.value))}
                  className="block w-full rounded-lg border border-[#2d334a] bg-[#171b31] py-2 px-3 text-white"
                />
              </div>
            </div>

            <div className="pt-2">
              <label className="flex items-center gap-3 text-sm text-slate-300 select-none">
                <input
                  type="checkbox"
                  checked={active}
                  onChange={(e) => setActive(e.target.checked)}
                  className="rounded border-[#2d334a] bg-[#171b31]"
                />
                Active immediately
              </label>
            </div>

            <button
              type="submit"
              disabled={creating}
              className="mt-4 flex w-full justify-center items-center rounded-lg bg-gradient-to-r from-[#8b5cf6] to-[#a855f7] py-2.5 px-4 font-semibold text-white shadow-md disabled:opacity-50 transition-all gap-2"
            >
              {creating ? "Creating..." : "Publish Banner Placement"}
            </button>
          </form>
        </div>
      </div>
    </div>
  );
}
