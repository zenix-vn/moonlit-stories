"use client";

import { useEffect, useState, use } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { api } from "../../../lib/api";
import { BookOpen, ArrowLeft, Save, Plus, Edit3, CheckCircle, EyeOff } from "lucide-react";

export default function StoryDetailPage({ params }: { params: Promise<{ id: string }> }) {
  const router = useRouter();
  const { id } = use(params);

  const [story, setStory] = useState<any>(null);
  const [episodes, setEpisodes] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [updating, setUpdating] = useState(false);
  const [error, setError] = useState("");
  const [success, setSuccess] = useState("");

  // Edit Story Form State
  const [title, setTitle] = useState("");
  const [slug, setSlug] = useState("");
  const [coverURL, setCoverURL] = useState("");
  const [hook, setHook] = useState("");
  const [description, setDescription] = useState("");
  const [freeEpisodeCount, setFreeEpisodeCount] = useState(3);
  const [defaultCoinPrice, setDefaultCoinPrice] = useState(20);
  const [status, setStatus] = useState("draft");
  const [isFeatured, setIsFeatured] = useState(false);
  const [isHot, setIsHot] = useState(false);
  const [isEditorPick, setIsEditorPick] = useState(false);

  // New Episode Inline Form State
  const [epNum, setEpNum] = useState(1);
  const [epTitle, setEpTitle] = useState("");
  const [epIsFree, setEpIsFree] = useState(false);
  const [epCoinPrice, setEpCoinPrice] = useState(20);
  const [epText, setEpText] = useState("");
  const [addingEpisode, setAddingEpisode] = useState(false);

  const loadData = async () => {
    try {
      const [storyData, epData] = await Promise.all([
        api.getStory(id),
        api.listEpisodes(id),
      ]);

      setStory(storyData);
      setEpisodes(epData);

      // Populate form
      setTitle(storyData.title);
      setSlug(storyData.slug);
      setCoverURL(storyData.cover_url || "");
      setHook(storyData.hook || "");
      setDescription(storyData.description || "");
      setFreeEpisodeCount(storyData.free_episode_count);
      setDefaultCoinPrice(storyData.default_coin_price);
      setStatus(storyData.status);
      setIsFeatured(storyData.is_featured);
      setIsHot(storyData.is_hot);
      setIsEditorPick(storyData.is_editor_pick);

      // Auto set next episode number
      if (epData.length > 0) {
        const maxNum = Math.max(...epData.map((e: any) => e.episode_number));
        setEpNum(maxNum + 1);
        setEpIsFree(maxNum + 1 <= storyData.free_episode_count);
      } else {
        setEpNum(1);
        setEpIsFree(true);
      }
    } catch (err: any) {
      setError(err.message || "Failed to load data");
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadData();
  }, [id]);

  const handleUpdateStory = async (e: React.FormEvent) => {
    e.preventDefault();
    setUpdating(true);
    setError("");
    setSuccess("");

    try {
      await api.updateStory(id, {
        title,
        slug,
        cover_url: coverURL,
        hook,
        description,
        free_episode_count: Number(freeEpisodeCount),
        default_coin_price: Number(defaultCoinPrice),
        status,
        is_featured: isFeatured,
        is_hot: isHot,
        is_editor_pick: isEditorPick,
      });
      setSuccess("Story metadata updated successfully!");
      loadData();
    } catch (err: any) {
      setError(err.message || "Failed to update story metadata");
    } finally {
      setUpdating(false);
    }
  };

  const handleCreateEpisode = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!epTitle) return;
    setAddingEpisode(true);
    setError("");

    try {
      await api.createEpisode(id, {
        episode_number: Number(epNum),
        title: epTitle,
        is_free: epIsFree,
        coin_price: epIsFree ? 0 : Number(epCoinPrice),
        content_text: epText,
        preview_text: epText.slice(0, 300) + "...", // Auto-preview snippet
      });

      // Clear Form
      setEpTitle("");
      setEpText("");
      loadData();
    } catch (err: any) {
      setError(err.message || "Failed to add episode");
    } finally {
      setAddingEpisode(false);
    }
  };

  if (loading) {
    return (
      <div className="flex h-64 items-center justify-center text-[#8b5cf6]">
        <BookOpen className="h-8 w-8 animate-spin" />
      </div>
    );
  }

  return (
    <div className="space-y-8">
      {/* Back header */}
      <div className="flex items-center gap-4">
        <Link href="/stories" className="text-[#94a3b8] hover:text-white transition-colors">
          <ArrowLeft className="h-6 w-6" />
        </Link>
        <div>
          <span className="text-xs font-semibold uppercase tracking-wider text-[#8b5cf6]">CMS Library</span>
          <h2 className="text-3xl font-bold tracking-tight text-white">{story?.title}</h2>
        </div>
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
        {/* Story Metadata Details Form */}
        <div className="rounded-xl border border-[#2d334a] bg-[#101426] p-6 shadow-md h-fit">
          <h3 className="text-lg font-semibold text-white mb-6">Book Details</h3>

          <form onSubmit={handleUpdateStory} className="space-y-4 text-sm">
            <div>
              <label className="block text-xs font-semibold uppercase tracking-wider text-[#94a3b8] mb-2">Title</label>
              <input
                type="text"
                required
                value={title}
                onChange={(e) => setTitle(e.target.value)}
                className="block w-full rounded-lg border border-[#2d334a] bg-[#171b31] py-2 px-3 text-white focus:border-[#8b5cf6] focus:outline-none focus:ring-1"
              />
            </div>

            <div>
              <label className="block text-xs font-semibold uppercase tracking-wider text-[#94a3b8] mb-2">Slug</label>
              <input
                type="text"
                required
                value={slug}
                onChange={(e) => setSlug(e.target.value)}
                className="block w-full rounded-lg border border-[#2d334a] bg-[#171b31] py-2 px-3 font-mono text-white focus:border-[#8b5cf6] focus:outline-none focus:ring-1"
              />
            </div>

            <div>
              <label className="block text-xs font-semibold uppercase tracking-wider text-[#94a3b8] mb-2">Cover URL</label>
              <input
                type="text"
                value={coverURL}
                onChange={(e) => setCoverURL(e.target.value)}
                className="block w-full rounded-lg border border-[#2d334a] bg-[#171b31] py-2 px-3 text-white focus:border-[#8b5cf6] focus:outline-none focus:ring-1"
              />
            </div>

            <div>
              <label className="block text-xs font-semibold uppercase tracking-wider text-[#94a3b8] mb-2">Hook</label>
              <input
                type="text"
                value={hook}
                onChange={(e) => setHook(e.target.value)}
                className="block w-full rounded-lg border border-[#2d334a] bg-[#171b31] py-2 px-3 text-white focus:border-[#8b5cf6] focus:outline-none focus:ring-1"
              />
            </div>

            <div>
              <label className="block text-xs font-semibold uppercase tracking-wider text-[#94a3b8] mb-2">Synopsis</label>
              <textarea
                value={description}
                onChange={(e) => setDescription(e.target.value)}
                rows={4}
                className="block w-full rounded-lg border border-[#2d334a] bg-[#171b31] py-2 px-3 text-white focus:border-[#8b5cf6] focus:outline-none focus:ring-1"
              />
            </div>

            <div className="grid grid-cols-2 gap-4">
              <div>
                <label className="block text-xs font-semibold uppercase tracking-wider text-[#94a3b8] mb-2">Free Chapters</label>
                <input
                  type="number"
                  value={freeEpisodeCount}
                  onChange={(e) => setFreeEpisodeCount(Number(e.target.value))}
                  className="block w-full rounded-lg border border-[#2d334a] bg-[#171b31] py-2 px-3 text-white"
                />
              </div>
              <div>
                <label className="block text-xs font-semibold uppercase tracking-wider text-[#94a3b8] mb-2">Default Price</label>
                <input
                  type="number"
                  value={defaultCoinPrice}
                  onChange={(e) => setDefaultCoinPrice(Number(e.target.value))}
                  className="block w-full rounded-lg border border-[#2d334a] bg-[#171b31] py-2 px-3 text-white"
                />
              </div>
            </div>

            <div>
              <label className="block text-xs font-semibold uppercase tracking-wider text-[#94a3b8] mb-2">Publish Status</label>
              <select
                value={status}
                onChange={(e) => setStatus(e.target.value)}
                className="block w-full rounded-lg border border-[#2d334a] bg-[#171b31] py-2.5 px-3 text-white focus:border-[#8b5cf6] focus:outline-none"
              >
                <option value="draft">Draft</option>
                <option value="published">Published</option>
                <option value="archived">Archived</option>
              </select>
            </div>

            <div className="space-y-2 pt-2">
              <label className="flex items-center gap-3 text-sm text-slate-300 select-none">
                <input
                  type="checkbox"
                  checked={isFeatured}
                  onChange={(e) => setIsFeatured(e.target.checked)}
                  className="rounded border-[#2d334a] bg-[#171b31] text-[#8b5cf6] focus:ring-[#8b5cf6]"
                />
                Home Featured Banner
              </label>

              <label className="flex items-center gap-3 text-sm text-slate-300 select-none">
                <input
                  type="checkbox"
                  checked={isHot}
                  onChange={(e) => setIsHot(e.target.checked)}
                  className="rounded border-[#2d334a] bg-[#171b31] text-[#8b5cf6] focus:ring-[#8b5cf6]"
                />
                Trending Hot Label
              </label>

              <label className="flex items-center gap-3 text-sm text-slate-300 select-none">
                <input
                  type="checkbox"
                  checked={isEditorPick}
                  onChange={(e) => setIsEditorPick(e.target.checked)}
                  className="rounded border-[#2d334a] bg-[#171b31] text-[#8b5cf6] focus:ring-[#8b5cf6]"
                />
                Tonights Editor Pick
              </label>
            </div>

            <button
              type="submit"
              disabled={updating}
              className="mt-6 flex w-full justify-center items-center rounded-lg bg-[#8b5cf6] hover:bg-[#7c3aed] py-2.5 px-4 font-semibold text-white transition-colors gap-2"
            >
              <Save className="h-4 w-4" />
              {updating ? "Saving..." : "Save Metadata"}
            </button>
          </form>
        </div>

        {/* Episode Management list & creation form */}
        <div className="lg:col-span-2 space-y-6">
          {/* Episode List */}
          <div className="rounded-xl border border-[#2d334a] bg-[#101426] p-6 shadow-md">
            <h3 className="text-lg font-semibold text-white mb-6">Episodes Checklist</h3>

            <div className="overflow-x-auto">
              <table className="w-full text-left text-sm border-collapse">
                <thead>
                  <tr className="border-b border-[#2d334a] text-[#94a3b8] font-semibold">
                    <th className="pb-3 pr-4">Num</th>
                    <th className="pb-3 pr-4">Chapter Title</th>
                    <th className="pb-3 pr-4">Pricing</th>
                    <th className="pb-3 pr-4">Status</th>
                    <th className="pb-3 text-right">Action</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-[#2d334a]/40 text-slate-300">
                  {episodes.map((ep) => (
                    <tr key={ep.id} className="hover:bg-[#171b31]/30 transition-colors">
                      <td className="py-3 pr-4 font-mono text-xs text-[#94a3b8]">Ep {ep.episode_number}</td>
                      <td className="py-3 pr-4 font-semibold text-slate-200">{ep.title}</td>
                      <td className="py-3 pr-4">
                        {ep.is_free ? (
                          <span className="text-xs text-emerald-400 font-semibold">Free</span>
                        ) : (
                          <span className="text-xs text-amber-400 font-semibold">{ep.coin_price} Coins</span>
                        )}
                      </td>
                      <td className="py-3 pr-4">
                        {ep.status === "published" ? (
                          <span className="inline-flex items-center text-[10px] uppercase font-bold text-emerald-400 gap-1">
                            <CheckCircle className="h-3.5 w-3.5" /> Published
                          </span>
                        ) : (
                          <span className="inline-flex items-center text-[10px] uppercase font-bold text-yellow-400 gap-1">
                            <EyeOff className="h-3.5 w-3.5" /> Draft
                          </span>
                        )}
                      </td>
                      <td className="py-3 text-right">
                        <Link
                          href={`/stories/${id}/episodes/${ep.id}`}
                          className="inline-flex items-center px-2.5 py-1 text-xs text-[#94a3b8] hover:text-[#8b5cf6] hover:bg-[#8b5cf6]/10 rounded border border-[#2d334a] transition-all gap-1"
                        >
                          <Edit3 className="h-3 w-3" />
                          Edit Text
                        </Link>
                      </td>
                    </tr>
                  ))}
                  {episodes.length === 0 && (
                    <tr>
                      <td colSpan={5} className="py-6 text-center text-[#94a3b8]">
                        No episodes added yet. Add the first chapter below.
                      </td>
                    </tr>
                  )}
                </tbody>
              </table>
            </div>
          </div>

          {/* Quick Add Episode Form */}
          <div className="rounded-xl border border-[#2d334a] bg-[#101426] p-6 shadow-md">
            <h3 className="text-lg font-semibold text-white mb-6 flex items-center gap-2">
              <Plus className="h-5 w-5 text-[#8b5cf6]" />
              Write Next Episode
            </h3>

            <form onSubmit={handleCreateEpisode} className="space-y-4 text-sm">
              <div className="grid grid-cols-3 gap-4">
                <div>
                  <label className="block text-xs font-semibold uppercase tracking-wider text-[#94a3b8] mb-2">Number</label>
                  <input
                    type="number"
                    required
                    value={epNum}
                    onChange={(e) => setEpNum(Number(e.target.value))}
                    className="block w-full rounded-lg border border-[#2d334a] bg-[#171b31] py-2 px-3 text-white"
                  />
                </div>
                <div className="col-span-2">
                  <label className="block text-xs font-semibold uppercase tracking-wider text-[#94a3b8] mb-2">Episode Title</label>
                  <input
                    type="text"
                    required
                    value={epTitle}
                    onChange={(e) => setEpTitle(e.target.value)}
                    className="block w-full rounded-lg border border-[#2d334a] bg-[#171b31] py-2 px-3 text-white placeholder-slate-500"
                    placeholder="e.g. Chapter 1: The Trap"
                  />
                </div>
              </div>

              <div className="grid grid-cols-2 gap-4">
                <div className="flex items-center gap-3">
                  <label className="flex items-center gap-3 text-sm text-slate-300 select-none mt-6">
                    <input
                      type="checkbox"
                      checked={epIsFree}
                      onChange={(e) => {
                        setEpIsFree(e.target.checked);
                        if (e.target.checked) setEpCoinPrice(0);
                      }}
                      className="rounded border-[#2d334a] bg-[#171b31]"
                    />
                    Free Episode
                  </label>
                </div>
                {!epIsFree && (
                  <div>
                    <label className="block text-xs font-semibold uppercase tracking-wider text-[#94a3b8] mb-2">Coins Price</label>
                    <input
                      type="number"
                      required
                      value={epCoinPrice}
                      onChange={(e) => setEpCoinPrice(Number(e.target.value))}
                      className="block w-full rounded-lg border border-[#2d334a] bg-[#171b31] py-2 px-3 text-white"
                    />
                  </div>
                )}
              </div>

              <div>
                <label className="block text-xs font-semibold uppercase tracking-wider text-[#94a3b8] mb-2">Content Body (Text)</label>
                <textarea
                  required
                  value={epText}
                  onChange={(e) => setEpText(e.target.value)}
                  rows={8}
                  className="block w-full rounded-lg border border-[#2d334a] bg-[#171b31] py-3 px-4 font-serif text-slate-200 placeholder-slate-500 focus:border-[#8b5cf6] focus:outline-none"
                  placeholder="Paste episode text here..."
                />
              </div>

              <button
                type="submit"
                disabled={addingEpisode}
                className="flex justify-center items-center rounded-lg bg-gradient-to-r from-[#8b5cf6] to-[#a855f7] hover:from-[#7c3aed] hover:to-[#9333ea] py-2.5 px-4 font-semibold text-white shadow-md disabled:opacity-50 transition-all gap-2"
              >
                <Plus className="h-5 w-5" />
                {addingEpisode ? "Saving..." : "Add Episode Chapter"}
              </button>
            </form>
          </div>
        </div>
      </div>
    </div>
  );
}
