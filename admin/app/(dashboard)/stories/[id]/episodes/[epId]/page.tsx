"use client";

import { useEffect, useState, use } from "react";
import Link from "next/link";
import { api } from "../../../../../lib/api";
import { ArrowLeft, Save, Loader2, Headphones, UploadCloud } from "lucide-react";

type AudioVoiceForm = {
  name: string;
  url: string;
};

const defaultAudioVoices: AudioVoiceForm[] = [
  { name: "Reader 1", url: "" },
  { name: "Reader 2", url: "" },
  { name: "Reader 3", url: "" },
];

export default function EpisodeEditorPage({
  params,
}: {
  params: Promise<{ id: string; epId: string }>;
}) {
  const { id, epId } = use(params);

  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState("");
  const [success, setSuccess] = useState("");
  const [uploadingAudioIndex, setUploadingAudioIndex] = useState<number | null>(null);

  // Form State
  const [title, setTitle] = useState("");
  const [slug, setSlug] = useState("");
  const [epNum, setEpNum] = useState(1);
  const [isFree, setIsFree] = useState(false);
  const [coinPrice, setCoinPrice] = useState(20);
  const [status, setStatus] = useState("draft");
  const [contentText, setContentText] = useState("");
  const [previewText, setPreviewText] = useState("");
  const [audioVoices, setAudioVoices] = useState<AudioVoiceForm[]>(defaultAudioVoices);

  useEffect(() => {
    api.getEpisode(epId)
      .then((data) => {
        setTitle(data.title);
        setSlug(data.slug || "");
        setEpNum(data.episode_number);
        setIsFree(data.is_free);
        setCoinPrice(data.coin_price || 20);
        setStatus(data.status);
        setContentText(data.content_text || "");
        setPreviewText(data.preview_text || "");
        setAudioVoices([
          { name: data.audio_voice_1_name || "Reader 1", url: data.audio_url_1 || data.audio_url || "" },
          { name: data.audio_voice_2_name || "Reader 2", url: data.audio_url_2 || "" },
          { name: data.audio_voice_3_name || "Reader 3", url: data.audio_url_3 || "" },
        ]);
        setLoading(false);
      })
      .catch((err) => {
        setError(err.message || "Failed to load episode details");
        setLoading(false);
      });
  }, [epId]);

  const handleUpdate = async (e: React.FormEvent) => {
    e.preventDefault();
    setSaving(true);
    setError("");
    setSuccess("");

    try {
      await api.updateEpisode(epId, {
        title,
        slug,
        episode_number: Number(epNum),
        is_free: isFree,
        coin_price: isFree ? 0 : Number(coinPrice),
        content_text: contentText,
        preview_text: previewText || contentText.slice(0, 300) + "...",
        audio_url: audioVoices[0]?.url || null,
        audio_voice_1_name: audioVoices[0]?.name || "Reader 1",
        audio_url_1: audioVoices[0]?.url || null,
        audio_voice_2_name: audioVoices[1]?.name || "Reader 2",
        audio_url_2: audioVoices[1]?.url || null,
        audio_voice_3_name: audioVoices[2]?.name || "Reader 3",
        audio_url_3: audioVoices[2]?.url || null,
        status,
      });

      setSuccess("Episode updated successfully!");
    } catch (err: unknown) {
      setError(err instanceof Error ? err.message : "Failed to save episode content");
    } finally {
      setSaving(false);
    }
  };

  const getWordCount = () => {
    if (!contentText) return 0;
    return contentText.trim().split(/\s+/).length;
  };

  const getReadTime = () => {
    // 200 words per minute average
    const minutes = Math.ceil(getWordCount() / 200);
    return minutes;
  };

  const updateAudioVoice = (index: number, patch: Partial<AudioVoiceForm>) => {
    setAudioVoices((current) => current.map((voice, i) => (
      i === index ? { ...voice, ...patch } : voice
    )));
  };

  const handleAudioUpload = async (index: number, file: File | null) => {
    if (!file) return;
    setUploadingAudioIndex(index);
    setError("");
    setSuccess("");

    try {
      const uploaded = await api.uploadAudio(file);
      updateAudioVoice(index, { url: uploaded.url });
      setSuccess(`Audio uploaded for Voice ${index + 1}. Save content to apply it to this episode.`);
    } catch (err: unknown) {
      setError(err instanceof Error ? err.message : "Failed to upload audio");
    } finally {
      setUploadingAudioIndex(null);
    }
  };

  if (loading) {
    return (
      <div className="flex h-64 items-center justify-center text-[#8b5cf6]">
        <Loader2 className="h-8 w-8 animate-spin" />
      </div>
    );
  }

  return (
    <div className="space-y-8">
      {/* Back button header */}
      <div className="flex items-center gap-4">
        <Link href={`/stories/${id}`} className="text-[#94a3b8] hover:text-white transition-colors">
          <ArrowLeft className="h-6 w-6" />
        </Link>
        <div>
          <span className="text-xs font-semibold uppercase tracking-wider text-[#8b5cf6]">
            Story Chapter Editor
          </span>
          <h2 className="text-3xl font-bold tracking-tight text-white">
            {title || `Episode ${epNum}`}
          </h2>
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

      <form onSubmit={handleUpdate} className="grid gap-8 lg:grid-cols-3">
        {/* Editor body area */}
        <div className="lg:col-span-2 space-y-4">
          <div className="rounded-xl border border-[#2d334a] bg-[#101426] p-6 shadow-md flex flex-col gap-4">
            <div className="flex justify-between items-center pb-2 border-b border-[#2d334a]/30">
              <span className="text-sm font-semibold text-[#94a3b8]">Chapter Content</span>
              <div className="flex gap-4 text-xs text-[#94a3b8] font-mono">
                <span>Words: <strong className="text-slate-200">{getWordCount()}</strong></span>
                <span>Reading Time: <strong className="text-slate-200">{getReadTime()} min</strong></span>
              </div>
            </div>

            <div>
              <textarea
                required
                value={contentText}
                onChange={(e) => setContentText(e.target.value)}
                rows={20}
                className="block w-full rounded-lg border border-[#2d334a] bg-[#171b31] py-3.5 px-4 font-serif text-slate-100 placeholder-slate-500 focus:border-[#8b5cf6] focus:outline-none leading-relaxed text-base"
                placeholder="Write or paste your story chapter text here..."
              />
            </div>
          </div>
        </div>

        {/* Sidebar settings area */}
        <div className="space-y-6">
          <div className="rounded-xl border border-[#2d334a] bg-[#101426] p-6 shadow-md space-y-4 text-sm">
            <h3 className="text-lg font-semibold text-white mb-4">Settings</h3>

            <div>
              <label className="block text-xs font-semibold uppercase tracking-wider text-[#94a3b8] mb-2">
                Chapter Title
              </label>
              <input
                type="text"
                required
                value={title}
                onChange={(e) => setTitle(e.target.value)}
                className="block w-full rounded-lg border border-[#2d334a] bg-[#171b31] py-2 px-3 text-white focus:border-[#8b5cf6] focus:outline-none"
              />
            </div>

            <div className="grid grid-cols-2 gap-4">
              <div>
                <label className="block text-xs font-semibold uppercase tracking-wider text-[#94a3b8] mb-2">
                  Number
                </label>
                <input
                  type="number"
                  required
                  value={epNum}
                  onChange={(e) => setEpNum(Number(e.target.value))}
                  className="block w-full rounded-lg border border-[#2d334a] bg-[#171b31] py-2 px-3 text-white"
                />
              </div>

              <div>
                <label className="block text-xs font-semibold uppercase tracking-wider text-[#94a3b8] mb-2">
                  Slug
                </label>
                <input
                  type="text"
                  value={slug}
                  onChange={(e) => setSlug(e.target.value)}
                  className="block w-full rounded-lg border border-[#2d334a] bg-[#171b31] py-2 px-3 font-mono text-white text-xs"
                />
              </div>
            </div>

            <div className="pt-2 border-t border-[#2d334a]/30">
              <label className="flex items-center gap-3 text-slate-300 select-none">
                <input
                  type="checkbox"
                  checked={isFree}
                  onChange={(e) => {
                    setIsFree(e.target.checked);
                    if (e.target.checked) setCoinPrice(0);
                  }}
                  className="rounded border-[#2d334a] bg-[#171b31] text-[#8b5cf6]"
                />
                Free Chapter
              </label>
            </div>

            {!isFree && (
              <div>
                <label className="block text-xs font-semibold uppercase tracking-wider text-[#94a3b8] mb-2">
                  Coin Price
                </label>
                <input
                  type="number"
                  required
                  value={coinPrice}
                  onChange={(e) => setCoinPrice(Number(e.target.value))}
                  className="block w-full rounded-lg border border-[#2d334a] bg-[#171b31] py-2 px-3 text-white focus:border-[#8b5cf6] focus:outline-none"
                />
              </div>
            )}

            <div>
              <label className="block text-xs font-semibold uppercase tracking-wider text-[#94a3b8] mb-2">
                Release Status
              </label>
              <select
                value={status}
                onChange={(e) => setStatus(e.target.value)}
                className="block w-full rounded-lg border border-[#2d334a] bg-[#171b31] py-2.5 px-3 text-white focus:border-[#8b5cf6] focus:outline-none"
              >
                <option value="draft">Draft</option>
                <option value="published">Published</option>
              </select>
            </div>

            <div>
              <label className="block text-xs font-semibold uppercase tracking-wider text-[#94a3b8] mb-2">
                Custom Preview (Locked Snippet)
              </label>
              <textarea
                value={previewText}
                onChange={(e) => setPreviewText(e.target.value)}
                rows={3}
                className="block w-full rounded-lg border border-[#2d334a] bg-[#171b31] py-2 px-3 text-white text-xs"
                placeholder="Optional. Visible as preview snippet when chapter is locked..."
              />
            </div>

            <div className="pt-2 border-t border-[#2d334a]/30">
              <div className="mb-3 flex items-center gap-2">
                <Headphones className="h-4 w-4 text-[#8b5cf6]" />
                <label className="block text-xs font-semibold uppercase tracking-wider text-[#94a3b8]">
                  Audio Narration Voices
                </label>
              </div>

              <div className="space-y-4">
                {audioVoices.map((voice, index) => (
                  <div key={index} className="rounded-lg border border-[#2d334a]/70 bg-[#171b31]/70 p-3">
                    <div className="mb-2 grid grid-cols-[88px_1fr] gap-2">
                      <span className="py-2 text-xs font-semibold text-[#94a3b8]">Voice {index + 1}</span>
                      <input
                        type="text"
                        value={voice.name}
                        onChange={(e) => updateAudioVoice(index, { name: e.target.value })}
                        placeholder={`Reader ${index + 1}`}
                        className="block w-full rounded-lg border border-[#2d334a] bg-[#101426] py-2 px-3 text-white text-xs placeholder-slate-500 focus:border-[#8b5cf6] focus:outline-none"
                      />
                    </div>
                    <input
                      type="url"
                      value={voice.url}
                      onChange={(e) => updateAudioVoice(index, { url: e.target.value })}
                      placeholder={`https://cdn.example.com/audio/ep${epNum}-voice-${index + 1}.mp3`}
                      className="block w-full rounded-lg border border-[#2d334a] bg-[#101426] py-2 px-3 text-white text-xs placeholder-slate-500 focus:border-[#8b5cf6] focus:outline-none"
                    />
                    <label className="mt-2 flex cursor-pointer items-center justify-center gap-2 rounded-lg border border-[#8b5cf6]/40 bg-[#8b5cf6]/10 px-3 py-2 text-xs font-semibold text-[#c4b5fd] transition-colors hover:bg-[#8b5cf6]/20">
                      {uploadingAudioIndex === index ? (
                        <Loader2 className="h-3.5 w-3.5 animate-spin" />
                      ) : (
                        <UploadCloud className="h-3.5 w-3.5" />
                      )}
                      {uploadingAudioIndex === index ? "Uploading audio..." : "Upload audio file"}
                      <input
                        type="file"
                        accept="audio/mpeg,audio/mp4,audio/aac,audio/wav,audio/ogg,audio/webm,.mp3,.m4a,.aac,.wav,.ogg,.opus,.webm,.mp4"
                        className="sr-only"
                        disabled={uploadingAudioIndex !== null}
                        onChange={(e) => {
                          void handleAudioUpload(index, e.target.files?.[0] ?? null);
                          e.currentTarget.value = "";
                        }}
                      />
                    </label>
                    {voice.url && (
                      <audio controls src={voice.url} className="mt-2 h-8 w-full opacity-80" />
                    )}
                  </div>
                ))}
              </div>
              <p className="mt-2 text-[10px] text-[#94a3b8]">
                Voice 1 is also used as the app&apos;s default text-to-speech reader name. URL 1 remains compatible with the legacy audio_url field.
              </p>
            </div>

            <button
              type="submit"
              disabled={saving}
              className="w-full mt-4 flex justify-center items-center rounded-lg bg-[#8b5cf6] hover:bg-[#7c3aed] py-2.5 px-4 font-semibold text-white shadow-md disabled:opacity-50 transition-colors gap-2"
            >
              {saving ? (
                <Loader2 className="h-4 w-4 animate-spin" />
              ) : (
                <Save className="h-4 w-4" />
              )}
              {saving ? "Saving..." : "Save Content"}
            </button>
          </div>
        </div>
      </form>
    </div>
  );
}
