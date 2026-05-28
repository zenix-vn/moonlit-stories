"use client";

import { useEffect, useState, use } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { api } from "../../../lib/api";
import {
  BookOpen, ArrowLeft, Save, Plus, Edit3, CheckCircle,
  EyeOff, Globe, Archive, Trash2, Tag, Settings, ListOrdered, RefreshCw
} from "lucide-react";

type Tab = "episodes" | "settings" | "taxonomy";

export default function StoryDetailPage({ params }: { params: Promise<{ id: string }> }) {
  const router = useRouter();
  const { id } = use(params);

  const [story, setStory] = useState<any>(null);
  const [episodes, setEpisodes] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [updating, setUpdating] = useState(false);
  const [publishing, setPublishing] = useState(false);
  const [error, setError] = useState("");
  const [success, setSuccess] = useState("");
  const [activeTab, setActiveTab] = useState<Tab>("episodes");

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

  // Genres & Moods Tab State
  const [allGenres, setAllGenres] = useState<any[]>([]);
  const [allMoods, setAllMoods] = useState<any[]>([]);
  const [selectedGenreIds, setSelectedGenreIds] = useState<string[]>([]);
  const [selectedMoodIds, setSelectedMoodIds] = useState<string[]>([]);
  const [taxonomyLoading, setTaxonomyLoading] = useState(false);
  const [taxonomySaving, setTaxonomySaving] = useState(false);

  // New Episode Inline Form State
  const [epNum, setEpNum] = useState(1);
  const [epTitle, setEpTitle] = useState("");
  const [epIsFree, setEpIsFree] = useState(false);
  const [epCoinPrice, setEpCoinPrice] = useState(20);
  const [epText, setEpText] = useState("");
  const [addingEpisode, setAddingEpisode] = useState(false);
  const [deletingEpisodeId, setDeletingEpisodeId] = useState<string | null>(null);

  const loadData = async () => {
    try {
      const [storyData, epData] = await Promise.all([
        api.getStory(id),
        api.listEpisodes(id),
      ]);

      setStory(storyData);
      setEpisodes(epData);

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

  const loadTaxonomy = async () => {
    setTaxonomyLoading(true);
    try {
      const data = await api.getStoryGenresMoods(id);
      setAllGenres(data.all_genres || []);
      setAllMoods(data.all_moods || []);
      setSelectedGenreIds(data.selected_genre_ids || []);
      setSelectedMoodIds(data.selected_mood_ids || []);
    } catch (err: any) {
      setError("Failed to load genres & moods: " + (err.message || ""));
    } finally {
      setTaxonomyLoading(false);
    }
  };

  useEffect(() => {
    loadData();
  }, [id]);

  useEffect(() => {
    if (activeTab === "taxonomy" && allGenres.length === 0) {
      loadTaxonomy();
    }
  }, [activeTab]);

  const notify = (msg: string, isError = false) => {
    if (isError) { setError(msg); setSuccess(""); }
    else { setSuccess(msg); setError(""); }
    setTimeout(() => { setError(""); setSuccess(""); }, 4000);
  };

  const handleUpdateStory = async (e: React.FormEvent) => {
    e.preventDefault();
    setUpdating(true);
    try {
      await api.updateStory(id, {
        title, slug, cover_url: coverURL, hook, description,
        free_episode_count: Number(freeEpisodeCount),
        default_coin_price: Number(defaultCoinPrice),
        status, is_featured: isFeatured, is_hot: isHot, is_editor_pick: isEditorPick,
      });
      notify("Story metadata saved!");
      loadData();
    } catch (err: any) {
      notify(err.message || "Failed to update story", true);
    } finally {
      setUpdating(false);
    }
  };

  const handlePublish = async () => {
    const newStatus = story?.status === "published" ? "archived" : "published";
    setPublishing(true);
    try {
      await api.publishStory(id, newStatus as any);
      notify(newStatus === "published" ? "Story published!" : "Story archived.");
      loadData();
    } catch (err: any) {
      notify(err.message || "Failed to update status", true);
    } finally {
      setPublishing(false);
    }
  };

  const handleCreateEpisode = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!epTitle) return;
    setAddingEpisode(true);
    try {
      await api.createEpisode(id, {
        episode_number: Number(epNum),
        title: epTitle,
        is_free: epIsFree,
        coin_price: epIsFree ? 0 : Number(epCoinPrice),
        content_text: epText,
        preview_text: epText.slice(0, 300) + (epText.length > 300 ? "..." : ""),
      });
      setEpTitle(""); setEpText("");
      notify("Episode added!");
      loadData();
    } catch (err: any) {
      notify(err.message || "Failed to add episode", true);
    } finally {
      setAddingEpisode(false);
    }
  };

  const handleDeleteEpisode = async (episodeId: string, epTitle: string) => {
    if (!confirm(`Archive episode "${epTitle}"? It will be hidden from readers.`)) return;
    setDeletingEpisodeId(episodeId);
    try {
      await api.deleteEpisode(episodeId);
      notify("Episode archived.");
      loadData();
    } catch (err: any) {
      notify(err.message || "Failed to delete episode", true);
    } finally {
      setDeletingEpisodeId(null);
    }
  };

  const toggleGenre = (id: string) => {
    setSelectedGenreIds(prev =>
      prev.includes(id) ? prev.filter(x => x !== id) : [...prev, id]
    );
  };

  const toggleMood = (id: string) => {
    setSelectedMoodIds(prev =>
      prev.includes(id) ? prev.filter(x => x !== id) : [...prev, id]
    );
  };

  const handleSaveTaxonomy = async () => {
    setTaxonomySaving(true);
    try {
      await api.updateStoryGenresMoods(id, selectedGenreIds, selectedMoodIds);
      notify("Genres & Moods saved!");
    } catch (err: any) {
      notify(err.message || "Failed to save taxonomy", true);
    } finally {
      setTaxonomySaving(false);
    }
  };

  if (loading) {
    return (
      <div className="flex h-64 items-center justify-center text-[#8b5cf6]">
        <BookOpen className="h-8 w-8 animate-spin" />
      </div>
    );
  }

  const publishedCount = episodes.filter(e => e.status === "published").length;
  const draftCount = episodes.filter(e => e.status === "draft").length;

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between gap-4 flex-wrap">
        <div className="flex items-center gap-4">
          <Link href="/stories" className="text-[#94a3b8] hover:text-white transition-colors">
            <ArrowLeft className="h-6 w-6" />
          </Link>
          <div>
            <span className="text-xs font-semibold uppercase tracking-wider text-[#8b5cf6]">CMS Library</span>
            <h2 className="text-2xl font-bold tracking-tight text-white leading-tight">{story?.title}</h2>
            <div className="flex items-center gap-3 mt-1 flex-wrap">
              <span className={`text-xs font-bold px-2.5 py-0.5 rounded-full ${
                story?.status === "published" ? "bg-emerald-500/15 text-emerald-400" :
                story?.status === "archived" ? "bg-red-500/15 text-red-400" :
                "bg-yellow-500/15 text-yellow-400"
              }`}>{story?.status?.toUpperCase()}</span>
              <span className="text-xs text-[#94a3b8]">{episodes.length} episodes</span>
              <span className="text-xs text-emerald-400">{publishedCount} published</span>
              {draftCount > 0 && <span className="text-xs text-yellow-400">{draftCount} draft</span>}
            </div>
          </div>
        </div>

        {/* Publish / Archive Quick Action */}
        <button
          onClick={handlePublish}
          disabled={publishing}
          className={`flex items-center gap-2 px-4 py-2 rounded-lg font-semibold text-sm transition-all ${
            story?.status === "published"
              ? "bg-red-500/15 text-red-400 border border-red-500/30 hover:bg-red-500/25"
              : "bg-emerald-500/15 text-emerald-400 border border-emerald-500/30 hover:bg-emerald-500/25"
          }`}
        >
          {publishing ? (
            <RefreshCw className="h-4 w-4 animate-spin" />
          ) : story?.status === "published" ? (
            <Archive className="h-4 w-4" />
          ) : (
            <Globe className="h-4 w-4" />
          )}
          {story?.status === "published" ? "Archive Story" : "Publish Story"}
        </button>
      </div>

      {/* Alerts */}
      {error && (
        <div className="rounded-lg bg-red-950/50 border border-red-500/30 p-4 text-sm text-red-400">{error}</div>
      )}
      {success && (
        <div className="rounded-lg bg-emerald-950/50 border border-emerald-500/30 p-4 text-sm text-emerald-400">{success}</div>
      )}

      {/* Tabs */}
      <div className="flex gap-1 border-b border-[#2d334a]">
        {([
          { key: "episodes", icon: ListOrdered, label: `Episodes (${episodes.length})` },
          { key: "settings", icon: Settings, label: "Settings" },
          { key: "taxonomy", icon: Tag, label: "Genres & Moods" },
        ] as { key: Tab; icon: any; label: string }[]).map(({ key, icon: Icon, label }) => (
          <button
            key={key}
            onClick={() => setActiveTab(key)}
            className={`flex items-center gap-2 px-4 py-2.5 text-sm font-semibold border-b-2 transition-all -mb-px ${
              activeTab === key
                ? "border-[#8b5cf6] text-[#8b5cf6]"
                : "border-transparent text-[#94a3b8] hover:text-white"
            }`}
          >
            <Icon className="h-4 w-4" />
            {label}
          </button>
        ))}
      </div>

      {/* ====== TAB: EPISODES ====== */}
      {activeTab === "episodes" && (
        <div className="space-y-6">
          {/* Episode list */}
          <div className="rounded-xl border border-[#2d334a] bg-[#101426] shadow-md overflow-hidden">
            <div className="px-6 py-4 border-b border-[#2d334a] flex items-center justify-between">
              <h3 className="text-base font-semibold text-white">Episode Checklist</h3>
              <span className="text-xs text-[#94a3b8]">{publishedCount}/{episodes.length} published</span>
            </div>
            <div className="overflow-x-auto">
              <table className="w-full text-left text-sm">
                <thead>
                  <tr className="border-b border-[#2d334a] text-[#94a3b8] text-xs font-semibold uppercase tracking-wider">
                    <th className="px-6 py-3">#</th>
                    <th className="px-4 py-3">Title</th>
                    <th className="px-4 py-3">Access</th>
                    <th className="px-4 py-3">Words</th>
                    <th className="px-4 py-3">Status</th>
                    <th className="px-4 py-3 text-right">Actions</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-[#2d334a]/40">
                  {episodes.map((ep) => (
                    <tr key={ep.id} className="hover:bg-[#171b31]/40 transition-colors">
                      <td className="px-6 py-3 font-mono text-xs text-[#94a3b8]">Ep {ep.episode_number}</td>
                      <td className="px-4 py-3 font-semibold text-slate-200 max-w-[200px] truncate">{ep.title}</td>
                      <td className="px-4 py-3">
                        {ep.is_free ? (
                          <span className="text-xs bg-emerald-500/10 text-emerald-400 px-2 py-0.5 rounded-full font-semibold">Free</span>
                        ) : (
                          <span className="text-xs bg-amber-500/10 text-amber-400 px-2 py-0.5 rounded-full font-semibold">🪙 {ep.coin_price}</span>
                        )}
                      </td>
                      <td className="px-4 py-3 text-[#94a3b8] text-xs">{ep.word_count?.toLocaleString() || "—"}</td>
                      <td className="px-4 py-3">
                        {ep.status === "published" ? (
                          <span className="inline-flex items-center text-[10px] uppercase font-bold text-emerald-400 gap-1">
                            <CheckCircle className="h-3 w-3" /> Live
                          </span>
                        ) : ep.status === "archived" ? (
                          <span className="inline-flex items-center text-[10px] uppercase font-bold text-red-400 gap-1">
                            <Archive className="h-3 w-3" /> Archived
                          </span>
                        ) : (
                          <span className="inline-flex items-center text-[10px] uppercase font-bold text-yellow-400 gap-1">
                            <EyeOff className="h-3 w-3" /> Draft
                          </span>
                        )}
                      </td>
                      <td className="px-4 py-3 text-right">
                        <div className="flex items-center justify-end gap-2">
                          <Link
                            href={`/stories/${id}/episodes/${ep.id}`}
                            className="inline-flex items-center px-2.5 py-1 text-xs text-[#94a3b8] hover:text-[#8b5cf6] hover:bg-[#8b5cf6]/10 rounded border border-[#2d334a] transition-all gap-1"
                          >
                            <Edit3 className="h-3 w-3" /> Edit
                          </Link>
                          <button
                            onClick={() => handleDeleteEpisode(ep.id, ep.title)}
                            disabled={deletingEpisodeId === ep.id}
                            className="inline-flex items-center px-2 py-1 text-xs text-red-400/60 hover:text-red-400 hover:bg-red-500/10 rounded border border-transparent hover:border-red-500/20 transition-all"
                          >
                            <Trash2 className="h-3 w-3" />
                          </button>
                        </div>
                      </td>
                    </tr>
                  ))}
                  {episodes.length === 0 && (
                    <tr>
                      <td colSpan={6} className="py-10 text-center text-[#94a3b8] text-sm">
                        No episodes yet. Add the first chapter below ↓
                      </td>
                    </tr>
                  )}
                </tbody>
              </table>
            </div>
          </div>

          {/* Quick Add Episode Form */}
          <div className="rounded-xl border border-[#2d334a] bg-[#101426] p-6 shadow-md">
            <h3 className="text-base font-semibold text-white mb-5 flex items-center gap-2">
              <Plus className="h-4 w-4 text-[#8b5cf6]" /> Write Next Episode
            </h3>

            <form onSubmit={handleCreateEpisode} className="space-y-4 text-sm">
              <div className="grid grid-cols-3 gap-4">
                <div>
                  <label className="block text-xs font-semibold uppercase tracking-wider text-[#94a3b8] mb-2">Ep #</label>
                  <input type="number" required value={epNum}
                    onChange={(e) => setEpNum(Number(e.target.value))}
                    className="block w-full rounded-lg border border-[#2d334a] bg-[#171b31] py-2 px-3 text-white focus:border-[#8b5cf6] focus:outline-none" />
                </div>
                <div className="col-span-2">
                  <label className="block text-xs font-semibold uppercase tracking-wider text-[#94a3b8] mb-2">Episode Title</label>
                  <input type="text" required value={epTitle}
                    onChange={(e) => setEpTitle(e.target.value)}
                    placeholder="e.g. The Prince's Gambit"
                    className="block w-full rounded-lg border border-[#2d334a] bg-[#171b31] py-2 px-3 text-white placeholder-slate-500 focus:border-[#8b5cf6] focus:outline-none" />
                </div>
              </div>

              <div className="flex items-center gap-6">
                <label className="flex items-center gap-2 text-sm text-slate-300 select-none cursor-pointer">
                  <input type="checkbox" checked={epIsFree}
                    onChange={(e) => { setEpIsFree(e.target.checked); if (e.target.checked) setEpCoinPrice(0); }}
                    className="rounded border-[#2d334a] bg-[#171b31] text-[#8b5cf6]" />
                  Free Episode
                </label>
                {!epIsFree && (
                  <div className="flex items-center gap-2">
                    <label className="text-xs text-[#94a3b8]">Coins:</label>
                    <input type="number" value={epCoinPrice}
                      onChange={(e) => setEpCoinPrice(Number(e.target.value))}
                      className="w-20 rounded-lg border border-[#2d334a] bg-[#171b31] py-1.5 px-2 text-white text-sm focus:border-[#8b5cf6] focus:outline-none" />
                  </div>
                )}
              </div>

              <div>
                <label className="block text-xs font-semibold uppercase tracking-wider text-[#94a3b8] mb-2">Content Body</label>
                <textarea required value={epText}
                  onChange={(e) => setEpText(e.target.value)}
                  rows={10}
                  placeholder="Paste episode text here..."
                  className="block w-full rounded-lg border border-[#2d334a] bg-[#171b31] py-3 px-4 font-serif text-slate-200 placeholder-slate-500 focus:border-[#8b5cf6] focus:outline-none resize-none" />
                <p className="mt-1 text-xs text-[#94a3b8]">{epText.split(/\s+/).filter(Boolean).length} words</p>
              </div>

              <button type="submit" disabled={addingEpisode}
                className="flex items-center gap-2 rounded-lg bg-gradient-to-r from-[#8b5cf6] to-[#a855f7] hover:from-[#7c3aed] hover:to-[#9333ea] py-2.5 px-5 font-semibold text-white shadow-md disabled:opacity-50 transition-all">
                <Plus className="h-4 w-4" />
                {addingEpisode ? "Saving..." : "Add Episode"}
              </button>
            </form>
          </div>
        </div>
      )}

      {/* ====== TAB: SETTINGS ====== */}
      {activeTab === "settings" && (
        <div className="max-w-2xl">
          <div className="rounded-xl border border-[#2d334a] bg-[#101426] p-6 shadow-md">
            <h3 className="text-base font-semibold text-white mb-6">Story Metadata</h3>

            <form onSubmit={handleUpdateStory} className="space-y-5 text-sm">
              <div className="grid grid-cols-2 gap-4">
                <div>
                  <label className="block text-xs font-semibold uppercase tracking-wider text-[#94a3b8] mb-2">Title</label>
                  <input type="text" required value={title} onChange={(e) => setTitle(e.target.value)}
                    className="block w-full rounded-lg border border-[#2d334a] bg-[#171b31] py-2 px-3 text-white focus:border-[#8b5cf6] focus:outline-none" />
                </div>
                <div>
                  <label className="block text-xs font-semibold uppercase tracking-wider text-[#94a3b8] mb-2">Slug</label>
                  <input type="text" required value={slug} onChange={(e) => setSlug(e.target.value)}
                    className="block w-full rounded-lg border border-[#2d334a] bg-[#171b31] py-2 px-3 font-mono text-white focus:border-[#8b5cf6] focus:outline-none" />
                </div>
              </div>

              <div>
                <label className="block text-xs font-semibold uppercase tracking-wider text-[#94a3b8] mb-2">Cover Image URL</label>
                <input type="text" value={coverURL} onChange={(e) => setCoverURL(e.target.value)}
                  placeholder="https://..."
                  className="block w-full rounded-lg border border-[#2d334a] bg-[#171b31] py-2 px-3 text-white placeholder-slate-500 focus:border-[#8b5cf6] focus:outline-none" />
                {coverURL && (
                  <img src={coverURL} alt="Cover preview" className="mt-2 h-20 w-14 object-cover rounded-lg border border-[#2d334a]" onError={(e) => (e.currentTarget.style.display = "none")} />
                )}
              </div>

              <div>
                <label className="block text-xs font-semibold uppercase tracking-wider text-[#94a3b8] mb-2">Hook (Short Tagline)</label>
                <input type="text" value={hook} onChange={(e) => setHook(e.target.value)}
                  placeholder="She thought it was just a nanny job..."
                  className="block w-full rounded-lg border border-[#2d334a] bg-[#171b31] py-2 px-3 text-white placeholder-slate-500 focus:border-[#8b5cf6] focus:outline-none" />
              </div>

              <div>
                <label className="block text-xs font-semibold uppercase tracking-wider text-[#94a3b8] mb-2">Synopsis</label>
                <textarea value={description} onChange={(e) => setDescription(e.target.value)} rows={4}
                  className="block w-full rounded-lg border border-[#2d334a] bg-[#171b31] py-2 px-3 text-white focus:border-[#8b5cf6] focus:outline-none resize-none" />
              </div>

              <div className="grid grid-cols-3 gap-4">
                <div>
                  <label className="block text-xs font-semibold uppercase tracking-wider text-[#94a3b8] mb-2">Free Chapters</label>
                  <input type="number" min={0} value={freeEpisodeCount} onChange={(e) => setFreeEpisodeCount(Number(e.target.value))}
                    className="block w-full rounded-lg border border-[#2d334a] bg-[#171b31] py-2 px-3 text-white focus:border-[#8b5cf6] focus:outline-none" />
                </div>
                <div>
                  <label className="block text-xs font-semibold uppercase tracking-wider text-[#94a3b8] mb-2">Default Price</label>
                  <input type="number" min={0} value={defaultCoinPrice} onChange={(e) => setDefaultCoinPrice(Number(e.target.value))}
                    className="block w-full rounded-lg border border-[#2d334a] bg-[#171b31] py-2 px-3 text-white focus:border-[#8b5cf6] focus:outline-none" />
                </div>
                <div>
                  <label className="block text-xs font-semibold uppercase tracking-wider text-[#94a3b8] mb-2">Status</label>
                  <select value={status} onChange={(e) => setStatus(e.target.value)}
                    className="block w-full rounded-lg border border-[#2d334a] bg-[#171b31] py-2 px-3 text-white focus:border-[#8b5cf6] focus:outline-none">
                    <option value="draft">Draft</option>
                    <option value="published">Published</option>
                    <option value="archived">Archived</option>
                  </select>
                </div>
              </div>

              <div className="flex flex-wrap gap-5 pt-1">
                {([
                  { label: "Featured Banner", value: isFeatured, setter: setIsFeatured },
                  { label: "Trending Hot", value: isHot, setter: setIsHot },
                  { label: "Editor's Pick", value: isEditorPick, setter: setIsEditorPick },
                ] as { label: string; value: boolean; setter: (v: boolean) => void }[]).map(({ label, value, setter }) => (
                  <label key={label} className="flex items-center gap-2.5 text-sm text-slate-300 select-none cursor-pointer">
                    <input type="checkbox" checked={value} onChange={(e) => setter(e.target.checked)}
                      className="rounded border-[#2d334a] bg-[#171b31] text-[#8b5cf6] focus:ring-[#8b5cf6] h-4 w-4" />
                    {label}
                  </label>
                ))}
              </div>

              <div className="flex gap-3 pt-2">
                <button type="submit" disabled={updating}
                  className="flex items-center gap-2 rounded-lg bg-[#8b5cf6] hover:bg-[#7c3aed] py-2.5 px-5 font-semibold text-white transition-colors disabled:opacity-60">
                  <Save className="h-4 w-4" />
                  {updating ? "Saving..." : "Save Changes"}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* ====== TAB: GENRES & MOODS ====== */}
      {activeTab === "taxonomy" && (
        <div className="space-y-6 max-w-3xl">
          {taxonomyLoading ? (
            <div className="flex h-40 items-center justify-center text-[#8b5cf6]">
              <RefreshCw className="h-6 w-6 animate-spin" />
            </div>
          ) : (
            <>
              {/* Genres */}
              <div className="rounded-xl border border-[#2d334a] bg-[#101426] p-6 shadow-md">
                <h3 className="text-base font-semibold text-white mb-1">Genres</h3>
                <p className="text-xs text-[#94a3b8] mb-5">Select all genres that apply to this story.</p>
                <div className="flex flex-wrap gap-2.5">
                  {allGenres.map((genre) => {
                    const isSelected = selectedGenreIds.includes(genre.id);
                    return (
                      <button key={genre.id} type="button" onClick={() => toggleGenre(genre.id)}
                        className={`px-3.5 py-1.5 rounded-full text-sm font-semibold border transition-all ${
                          isSelected
                            ? "bg-[#8b5cf6] border-[#8b5cf6] text-white shadow-[0_0_12px_rgba(139,92,246,0.4)]"
                            : "bg-[#171b31] border-[#2d334a] text-[#94a3b8] hover:border-[#8b5cf6]/40 hover:text-white"
                        }`}>
                        {genre.name}
                        {isSelected && <span className="ml-1.5 text-white/70">✓</span>}
                      </button>
                    );
                  })}
                  {allGenres.length === 0 && (
                    <p className="text-sm text-[#94a3b8]">No genres found in database.</p>
                  )}
                </div>
              </div>

              {/* Moods */}
              <div className="rounded-xl border border-[#2d334a] bg-[#101426] p-6 shadow-md">
                <h3 className="text-base font-semibold text-white mb-1">Moods</h3>
                <p className="text-xs text-[#94a3b8] mb-5">Select the emotional tone(s) of this story.</p>
                <div className="flex flex-wrap gap-2.5">
                  {allMoods.map((mood) => {
                    const isSelected = selectedMoodIds.includes(mood.id);
                    return (
                      <button key={mood.id} type="button" onClick={() => toggleMood(mood.id)}
                        className={`px-3.5 py-1.5 rounded-full text-sm font-semibold border transition-all ${
                          isSelected
                            ? "bg-[#ec4899] border-[#ec4899] text-white shadow-[0_0_12px_rgba(236,72,153,0.4)]"
                            : "bg-[#171b31] border-[#2d334a] text-[#94a3b8] hover:border-[#ec4899]/40 hover:text-white"
                        }`}>
                        {mood.name}
                        {isSelected && <span className="ml-1.5 text-white/70">✓</span>}
                      </button>
                    );
                  })}
                  {allMoods.length === 0 && (
                    <p className="text-sm text-[#94a3b8]">No moods found in database.</p>
                  )}
                </div>
              </div>

              {/* Save button */}
              <div className="flex items-center gap-4">
                <button onClick={handleSaveTaxonomy} disabled={taxonomySaving}
                  className="flex items-center gap-2 rounded-lg bg-[#8b5cf6] hover:bg-[#7c3aed] py-2.5 px-5 font-semibold text-white transition-colors disabled:opacity-60">
                  <Save className="h-4 w-4" />
                  {taxonomySaving ? "Saving..." : "Save Genres & Moods"}
                </button>
                <span className="text-xs text-[#94a3b8]">
                  {selectedGenreIds.length} genre{selectedGenreIds.length !== 1 ? "s" : ""} · {selectedMoodIds.length} mood{selectedMoodIds.length !== 1 ? "s" : ""} selected
                </span>
              </div>
            </>
          )}
        </div>
      )}
    </div>
  );
}
