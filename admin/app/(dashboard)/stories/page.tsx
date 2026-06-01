"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { api } from "../../lib/api";
import { BookOpen, Plus, Eye, Edit3, Trash, Sparkles, Wand2, RefreshCw, X } from "lucide-react";

export default function StoriesPage() {
  const [stories, setStories] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");

  // Creation Mode Switcher
  const [creationMode, setCreationMode] = useState<"manual" | "ai">("manual");

  // Create Story Form State
  const [newTitle, setNewTitle] = useState("");
  const [newSlug, setNewSlug] = useState("");
  const [newDesc, setNewDesc] = useState("");
  const [newHook, setNewHook] = useState("");
  const [newCover, setNewCover] = useState("");
  const [freeEpCount, setFreeEpCount] = useState(3);
  const [defaultPrice, setDefaultPrice] = useState(20);
  const [creating, setCreating] = useState(false);

  // AI Outline Generation State
  const [aiPrompt, setAiPrompt] = useState("");
  const [aiGenerating, setAiGenerating] = useState(false);
  const [generatedOutline, setGeneratedOutline] = useState<any>(null);
  const [savingAI, setSavingAI] = useState(false);

  const fetchStories = async () => {
    try {
      const data = await api.listStories();
      setStories(data);
    } catch (err: any) {
      setError(err.message || "Failed to load stories");
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchStories();
  }, []);

  const handleGenerateOutline = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!aiPrompt.trim()) return;
    setAiGenerating(true);
    setError("");
    try {
      const data = await api.generateAIStoryOutline(aiPrompt);
      if (data.error) {
        throw new Error(data.error);
      }
      setGeneratedOutline(data);
    } catch (err: any) {
      setError(err.message || "Failed to generate story outline. Make sure OPENROUTER_API_KEY is configured on the backend.");
    } finally {
      setAiGenerating(false);
    }
  };

  const handleSaveAIOutline = async () => {
    if (!generatedOutline) return;
    setSavingAI(true);
    setError("");
    try {
      await api.saveAIStoryOutline(generatedOutline);
      setGeneratedOutline(null);
      setAiPrompt("");
      fetchStories();
    } catch (err: any) {
      setError(err.message || "Failed to save generated story outline.");
    } finally {
      setSavingAI(false);
    }
  };

  const handleCreateStory = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!newTitle || !newSlug) return;
    setCreating(true);

    try {
      await api.createStory({
        title: newTitle,
        slug: newSlug,
        description: newDesc,
        hook: newHook,
        cover_url: newCover,
        free_episode_count: Number(freeEpCount),
        default_coin_price: Number(defaultPrice),
      });

      // Clear Form
      setNewTitle("");
      setNewSlug("");
      setNewDesc("");
      setNewHook("");
      setNewCover("");
      fetchStories();
    } catch (err: any) {
      setError(err.message || "Failed to create story");
    } finally {
      setCreating(false);
    }
  };

  const handleTitleChange = (val: string) => {
    setNewTitle(val);
    // Generate simple slug automatically
    setNewSlug(
      val
        .toLowerCase()
        .replace(/[^a-z0-9]+/g, "-")
        .replace(/(^-|-$)/g, "")
    );
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
      <div>
        <h2 className="text-3xl font-bold tracking-tight text-white">Stories & Library CMS</h2>
        <p className="text-sm text-[#94a3b8]">
          Manage books, upload covers, and publish new chapters
        </p>
      </div>

      {error && (
        <div className="rounded-lg bg-red-950/50 border border-red-500/30 p-4 text-sm text-red-400">
          {error}
        </div>
      )}

      <div className="grid gap-8 lg:grid-cols-3">
        {/* Stories list */}
        <div className="lg:col-span-2 space-y-4">
          <h3 className="text-lg font-semibold text-white">All Stories ({stories.length})</h3>

          <div className="grid gap-4 sm:grid-cols-2">
            {stories.map((story) => (
              <div
                key={story.id}
                className="flex flex-col rounded-xl border border-[#2d334a] bg-[#101426] overflow-hidden hover:border-[#8b5cf6]/50 transition-all duration-200"
              >
                {/* Book Thumbnail / Cover Header */}
                <div className="h-32 bg-[#171b31] relative flex items-center justify-center overflow-hidden">
                  {story.cover_url ? (
                    <img
                      src={story.cover_url}
                      alt={story.title}
                      className="w-full h-full object-cover opacity-60"
                    />
                  ) : (
                    <BookOpen className="h-10 w-10 text-[#94a3b8]" />
                  )}
                  <div className="absolute top-3 right-3">
                    <span className={`inline-flex items-center rounded-md px-2 py-0.5 text-xs font-semibold uppercase tracking-wider ${
                      story.status === "published" ? "bg-emerald-500/20 text-emerald-400 border border-emerald-500/30" :
                      story.status === "archived" ? "bg-slate-500/20 text-slate-400" :
                      "bg-yellow-500/20 text-yellow-400 border border-yellow-500/30"
                    }`}>
                      {story.status}
                    </span>
                  </div>
                </div>

                {/* Details */}
                <div className="p-5 flex-1 flex flex-col justify-between">
                  <div>
                    <h4 className="font-bold text-white text-lg line-clamp-1">{story.title}</h4>
                    <p className="text-xs font-mono text-[#94a3b8] mt-1">/{story.slug}</p>
                    <p className="text-xs text-[#94a3b8] mt-3 line-clamp-2">{story.description || "No description provided."}</p>
                  </div>

                  <div className="mt-5 pt-4 border-t border-[#2d334a]/40 flex items-center justify-between">
                    <div className="text-xs text-[#94a3b8]">
                      <span className="font-semibold text-slate-200">{story.total_episodes}</span> Episodes
                    </div>

                    <Link
                      href={`/stories/${story.id}`}
                      className="flex items-center px-3 py-1.5 text-xs font-semibold text-white bg-[#8b5cf6] hover:bg-[#7c3aed] rounded-lg transition-colors gap-1.5"
                    >
                      <Edit3 className="h-3.5 w-3.5" />
                      Manage Book
                    </Link>
                  </div>
                </div>
              </div>
            ))}
          </div>
        </div>

        {/* Add story form */}
        <div className="rounded-xl border border-[#2d334a] bg-[#101426] p-6 shadow-md h-fit space-y-6">
          {/* Creation Mode Switcher */}
          <div className="flex border-b border-[#2d334a]">
            <button
              onClick={() => setCreationMode("manual")}
              className={`flex-1 pb-3 text-sm font-semibold border-b-2 transition-all ${
                creationMode === "manual"
                  ? "border-[#8b5cf6] text-[#8b5cf6]"
                  : "border-transparent text-[#94a3b8] hover:text-white"
              }`}
            >
              Manual Create
            </button>
            <button
              onClick={() => setCreationMode("ai")}
              className={`flex-1 pb-3 text-sm font-semibold border-b-2 transition-all flex items-center justify-center gap-1.5 ${
                creationMode === "ai"
                  ? "border-[#8b5cf6] text-[#8b5cf6]"
                  : "border-transparent text-[#94a3b8] hover:text-white"
              }`}
            >
              <Sparkles className="h-4 w-4 text-[#8b5cf6]" />
              AI Generator
            </button>
          </div>

          {creationMode === "manual" ? (
            <div>
              <h3 className="text-lg font-semibold text-white mb-6 flex items-center gap-2">
                <Plus className="h-5 w-5 text-[#8b5cf6]" />
                Create New Story
              </h3>

              <form onSubmit={handleCreateStory} className="space-y-4 text-sm">
                <div>
                  <label className="block text-xs font-semibold uppercase tracking-wider text-[#94a3b8] mb-2">
                    Book Title
                  </label>
                  <input
                    type="text"
                    required
                    value={newTitle}
                    onChange={(e) => handleTitleChange(e.target.value)}
                    className="block w-full rounded-lg border border-[#2d334a] bg-[#171b31] py-2 px-3 text-white placeholder-slate-500 focus:border-[#8b5cf6] focus:outline-none focus:ring-1 focus:ring-[#8b5cf6]"
                    placeholder="e.g. The Billionaire Fake Wife"
                  />
                </div>

                <div>
                  <label className="block text-xs font-semibold uppercase tracking-wider text-[#94a3b8] mb-2">
                    Slug (URL Segment)
                  </label>
                  <input
                    type="text"
                    required
                    value={newSlug}
                    onChange={(e) => setNewSlug(e.target.value)}
                    className="block w-full rounded-lg border border-[#2d334a] bg-[#171b31] py-2 px-3 font-mono text-white placeholder-slate-500 focus:border-[#8b5cf6] focus:outline-none focus:ring-1 focus:ring-[#8b5cf6]"
                    placeholder="the-billionaire-fake-wife"
                  />
                </div>

                <div>
                  <label className="block text-xs font-semibold uppercase tracking-wider text-[#94a3b8] mb-2">
                    Cover Image URL
                  </label>
                  <input
                    type="text"
                    value={newCover}
                    onChange={(e) => setNewCover(e.target.value)}
                    className="block w-full rounded-lg border border-[#2d334a] bg-[#171b31] py-2 px-3 text-white placeholder-slate-500 focus:border-[#8b5cf6] focus:outline-none focus:ring-1 focus:ring-[#8b5cf6]"
                    placeholder="https://images.unsplash.com/photo-..."
                  />
                </div>

                <div>
                  <label className="block text-xs font-semibold uppercase tracking-wider text-[#94a3b8] mb-2">
                    Book Hook / Tagline
                  </label>
                  <input
                    type="text"
                    value={newHook}
                    onChange={(e) => setNewHook(e.target.value)}
                    className="block w-full rounded-lg border border-[#2d334a] bg-[#171b31] py-2 px-3 text-white placeholder-slate-500 focus:border-[#8b5cf6] focus:outline-none focus:ring-1 focus:ring-[#8b5cf6]"
                    placeholder="e.g. She signed a contract, but..."
                  />
                </div>

                <div>
                  <label className="block text-xs font-semibold uppercase tracking-wider text-[#94a3b8] mb-2">
                    Description
                  </label>
                  <textarea
                    value={newDesc}
                    onChange={(e) => setNewDesc(e.target.value)}
                    rows={3}
                    className="block w-full rounded-lg border border-[#2d334a] bg-[#171b31] py-2 px-3 text-white placeholder-slate-500 focus:border-[#8b5cf6] focus:outline-none focus:ring-1 focus:ring-[#8b5cf6]"
                    placeholder="Provide a brief synopsis of the series..."
                  />
                </div>

                <div className="grid grid-cols-2 gap-4">
                  <div>
                    <label className="block text-xs font-semibold uppercase tracking-wider text-[#94a3b8] mb-2">
                      Free Episodes
                    </label>
                    <input
                      type="number"
                      min="0"
                      value={freeEpCount}
                      onChange={(e) => setFreeEpCount(Number(e.target.value))}
                      className="block w-full rounded-lg border border-[#2d334a] bg-[#171b31] py-2 px-3 text-white focus:border-[#8b5cf6] focus:outline-none focus:ring-1 focus:ring-[#8b5cf6]"
                    />
                  </div>
                  <div>
                    <label className="block text-xs font-semibold uppercase tracking-wider text-[#94a3b8] mb-2">
                      Coin Price
                    </label>
                    <input
                      type="number"
                      min="0"
                      value={defaultPrice}
                      onChange={(e) => setDefaultPrice(Number(e.target.value))}
                      className="block w-full rounded-lg border border-[#2d334a] bg-[#171b31] py-2 px-3 text-white focus:border-[#8b5cf6] focus:outline-none focus:ring-1 focus:ring-[#8b5cf6]"
                    />
                  </div>
                </div>

                <button
                  type="submit"
                  disabled={creating}
                  className="mt-6 flex w-full justify-center items-center rounded-lg bg-gradient-to-r from-[#8b5cf6] to-[#a855f7] py-2.5 px-4 font-semibold text-white shadow-md hover:from-[#7c3aed] hover:to-[#9333ea] focus:outline-none focus:ring-2 focus:ring-[#8b5cf6] disabled:opacity-50 transition-all duration-200"
                >
                  {creating ? "Creating..." : "Create Story Draft"}
                </button>
              </form>
            </div>
          ) : (
            <div>
              <h3 className="text-lg font-semibold text-white mb-2 flex items-center gap-2">
                <Sparkles className="h-5 w-5 text-[#8b5cf6]" />
                Auto-Generate Novel
              </h3>
              <p className="text-xs text-[#94a3b8] mb-6">
                Tell the AI what you want to write (genre, themes, major tropes, characters). The AI will design a title, hook, detailed setting, characters list, and main plot outline.
              </p>

              <form onSubmit={handleGenerateOutline} className="space-y-4 text-sm">
                <div>
                  <label className="block text-xs font-semibold uppercase tracking-wider text-[#94a3b8] mb-2">
                    AI Prompt (Your Story Idea)
                  </label>
                  <textarea
                    required
                    value={aiPrompt}
                    onChange={(e) => setAiPrompt(e.target.value)}
                    rows={6}
                    className="block w-full rounded-lg border border-[#2d334a] bg-[#171b31] py-2.5 px-3.5 text-white placeholder-slate-500 focus:border-[#8b5cf6] focus:outline-none focus:ring-1 focus:ring-[#8b5cf6] resize-none"
                    placeholder="Describe your story idea. E.g.: 'A modern werewolf romance about a rejected human mate who discovers she is the lost heir to a legendary alpha dynasty. Key tropes: rejection, revenge, secret identity.'"
                  />
                </div>

                <button
                  type="submit"
                  disabled={aiGenerating}
                  className="mt-4 flex w-full justify-center items-center rounded-lg bg-gradient-to-r from-[#8b5cf6] to-[#a855f7] py-2.5 px-4 font-semibold text-white shadow-md hover:from-[#7c3aed] hover:to-[#9333ea] focus:outline-none focus:ring-2 focus:ring-[#8b5cf6] disabled:opacity-50 transition-all duration-200 gap-2"
                >
                  {aiGenerating ? (
                    <>
                      <RefreshCw className="h-4 w-4 animate-spin" />
                      Weaving story outline...
                    </>
                  ) : (
                    <>
                      <Wand2 className="h-4 w-4" />
                      Plan Story with AI
                    </>
                  )}
                </button>
              </form>
            </div>
          )}
        </div>
      </div>

      {/* Generated Outline Preview Modal */}
      {generatedOutline && (
        <div className="fixed inset-0 z-50 bg-black/80 backdrop-blur-sm flex items-center justify-center p-4 overflow-y-auto">
          <div className="bg-[#101426] border border-[#2d334a] rounded-2xl p-6 md:p-8 max-w-4xl w-full shadow-2xl max-h-[90vh] overflow-y-auto flex flex-col justify-between space-y-6">
            {/* Modal Header */}
            <div className="flex items-start justify-between border-b border-[#2d334a] pb-4">
              <div>
                <span className="text-xs font-bold text-[#8b5cf6] uppercase tracking-widest flex items-center gap-1.5">
                  <Sparkles className="h-3.5 w-3.5" /> AI Story Proposal
                </span>
                <h3 className="text-2xl font-bold text-white mt-1">{generatedOutline.title}</h3>
                <p className="text-sm italic text-purple-300/80 mt-1">"{generatedOutline.hook}"</p>
              </div>
              <button
                onClick={() => setGeneratedOutline(null)}
                className="text-[#94a3b8] hover:text-white transition-colors p-1"
              >
                <X className="h-6 w-6" />
              </button>
            </div>

            {/* Modal Body */}
            <div className="space-y-6 text-sm text-[#cbd5e1] leading-relaxed">
              {/* Description / Synopsis */}
              <div>
                <h4 className="text-xs uppercase tracking-wider font-bold text-slate-400 mb-2">Short Synopsis</h4>
                <div className="bg-[#171b31] border border-[#2d334a]/60 rounded-xl p-4">
                  {generatedOutline.description}
                </div>
              </div>

              {/* Setting */}
              <div>
                <h4 className="text-xs uppercase tracking-wider font-bold text-slate-400 mb-2">World Setting & Lore</h4>
                <div className="bg-[#171b31] border border-[#2d334a]/60 rounded-xl p-4 whitespace-pre-line">
                  {generatedOutline.setting}
                </div>
              </div>

              {/* Detailed Plot Outline */}
              <div>
                <h4 className="text-xs uppercase tracking-wider font-bold text-slate-400 mb-2">Full Narrative Arc Outline</h4>
                <div className="bg-[#171b31] border border-[#2d334a]/60 rounded-xl p-4 whitespace-pre-line">
                  {generatedOutline.outline}
                </div>
              </div>

              {/* Characters Sheet */}
              <div>
                <h4 className="text-xs uppercase tracking-wider font-bold text-slate-400 mb-2">Character Roster</h4>
                <div className="grid gap-4 sm:grid-cols-2">
                  {generatedOutline.characters?.map((c: any, index: number) => (
                    <div key={index} className="bg-[#171b31] border border-[#2d334a]/60 rounded-xl p-4">
                      <div className="flex items-center justify-between mb-1.5">
                        <span className="font-semibold text-white">{c.name}</span>
                        <span className="text-[10px] uppercase font-bold px-2 py-0.5 rounded bg-purple-500/10 text-purple-400 border border-purple-500/20">
                          {c.role}
                        </span>
                      </div>
                      <p className="text-xs text-[#94a3b8]">{c.description}</p>
                    </div>
                  ))}
                </div>
              </div>
            </div>

            {/* Modal Footer */}
            <div className="border-t border-[#2d334a] pt-5 flex items-center justify-end gap-4">
              <button
                type="button"
                onClick={() => setGeneratedOutline(null)}
                className="px-5 py-2.5 rounded-lg border border-[#2d334a] text-sm font-semibold text-[#94a3b8] hover:text-white transition-colors"
              >
                Discard
              </button>
              <button
                type="button"
                disabled={savingAI}
                onClick={handleSaveAIOutline}
                className="flex items-center gap-2 px-6 py-2.5 rounded-lg bg-gradient-to-r from-[#8b5cf6] to-[#a855f7] hover:from-[#7c3aed] hover:to-[#9333ea] text-sm font-semibold text-white shadow-md disabled:opacity-50 transition-all duration-200"
              >
                {savingAI ? (
                  <>
                    <RefreshCw className="h-4 w-4 animate-spin" />
                    Initializing Book...
                  </>
                ) : (
                  <>
                    <Plus className="h-4 w-4" />
                    Save & Create Book Draft
                  </>
                )}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
