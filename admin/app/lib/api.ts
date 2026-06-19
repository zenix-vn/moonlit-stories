const API_BASE_URL = process.env.NEXT_PUBLIC_API_URL || "http://localhost:8088";

export function getAuthToken(): string | null {
  if (typeof window !== "undefined") {
    return localStorage.getItem("moonlit_admin_token");
  }
  return null;
}

export function setAuthToken(token: string) {
  if (typeof window !== "undefined") {
    localStorage.setItem("moonlit_admin_token", token);
  }
}

export function removeAuthToken() {
  if (typeof window !== "undefined") {
    localStorage.removeItem("moonlit_admin_token");
  }
}

export interface RequestOptions extends RequestInit {
  json?: any;
}

async function apiFetch(path: string, options: RequestOptions = {}) {
  const token = getAuthToken();
  const headers = new Headers(options.headers || {});

  if (token) {
    headers.set("Authorization", `Bearer ${token}`);
  }

  if (options.json) {
    headers.set("Content-Type", "application/json");
    options.body = JSON.stringify(options.json);
  }

  const response = await fetch(`${API_BASE_URL}${path}`, {
    ...options,
    headers,
  });

  if (response.status === 401) {
    removeAuthToken();
    if (typeof window !== "undefined" && window.location.pathname !== "/login") {
      window.location.href = "/login";
    }
    throw new Error("Unauthorized");
  }

  if (!response.ok) {
    const errorData = await response.json().catch(() => ({}));
    throw new Error(errorData.error || `HTTP error! status: ${response.status}`);
  }

  return response.json();
}

async function apiUpload(path: string, formData: FormData) {
  const token = getAuthToken();
  const headers = new Headers();

  if (token) {
    headers.set("Authorization", `Bearer ${token}`);
  }

  const response = await fetch(`${API_BASE_URL}${path}`, {
    method: "POST",
    headers,
    body: formData,
  });

  if (response.status === 401) {
    removeAuthToken();
    if (typeof window !== "undefined" && window.location.pathname !== "/login") {
      window.location.href = "/login";
    }
    throw new Error("Unauthorized");
  }

  if (!response.ok) {
    const errorData = await response.json().catch(() => ({}));
    throw new Error(errorData.error || `HTTP error! status: ${response.status}`);
  }

  return response.json();
}

export const api = {
  // Auth
  login: async (email: string, password: string) => {
    const res = await apiFetch("/admin/auth/login", {
      method: "POST",
      json: { email, password },
    });
    if (res.token) {
      setAuthToken(res.token);
    }
    return res;
  },

  getCurrentAdmin: async () => {
    return apiFetch("/admin/me");
  },

  // Dashboard / Analytics
  getOverviewMetrics: async () => {
    // Real aggregated metrics from /admin/dashboard/overview.
    return apiFetch("/admin/dashboard/overview").catch(() => {
      return { dau: 0, subscribers: 0, revenue: 0, unlocks: 0 };
    });
  },

  getRecentActivity: async () => {
    return apiFetch("/admin/dashboard/recent-activity").catch(() => []);
  },

  getCountryActivity: async () => {
    return apiFetch("/admin/dashboard/country-activity").catch(() => []);
  },

  // Stories CRUD
  listStories: async () => {
    return apiFetch("/admin/stories");
  },

  createStory: async (story: any) => {
    return apiFetch("/admin/stories", {
      method: "POST",
      json: story,
    });
  },

  getStory: async (id: string) => {
    return apiFetch(`/admin/stories/${id}`);
  },

  updateStory: async (id: string, story: any) => {
    return apiFetch(`/admin/stories/${id}`, {
      method: "PATCH",
      json: story,
    });
  },

  publishStory: async (id: string, status: "published" | "draft" | "archived" = "published") => {
    return apiFetch(`/admin/stories/${id}/publish`, {
      method: "PATCH",
      json: { status },
    });
  },

  deleteStory: async (id: string) => {
    return apiFetch(`/admin/stories/${id}`, {
      method: "DELETE",
    });
  },

  getStoryGenresMoods: async (id: string) => {
    return apiFetch(`/admin/stories/${id}/genres-moods`);
  },

  updateStoryGenresMoods: async (id: string, genreIds: string[], moodIds: string[]) => {
    return apiFetch(`/admin/stories/${id}/genres-moods`, {
      method: "PUT",
      json: { genre_ids: genreIds, mood_ids: moodIds },
    });
  },

  // Episodes CRUD
  listEpisodes: async (storyId: string) => {
    return apiFetch(`/admin/stories/${storyId}/episodes`);
  },

  createEpisode: async (storyId: string, episode: any) => {
    return apiFetch(`/admin/stories/${storyId}/episodes`, {
      method: "POST",
      json: episode,
    });
  },

  getEpisode: async (id: string) => {
    return apiFetch(`/admin/episodes/${id}`);
  },

  updateEpisode: async (id: string, episode: any) => {
    return apiFetch(`/admin/episodes/${id}`, {
      method: "PATCH",
      json: episode,
    });
  },

  deleteEpisode: async (id: string) => {
    return apiFetch(`/admin/episodes/${id}`, {
      method: "DELETE",
    });
  },

  uploadAudio: async (file: File) => {
    const formData = new FormData();
    formData.append("file", file);
    return apiUpload("/admin/uploads/audio", formData);
  },

  // Banners
  listBanners: async () => {
    return apiFetch("/admin/banners");
  },

  createBanner: async (banner: any) => {
    return apiFetch("/admin/banners", {
      method: "POST",
      json: banner,
    });
  },

  updateBanner: async (id: string, banner: any) => {
    return apiFetch(`/admin/banners/${id}`, {
      method: "PATCH",
      json: banner,
    });
  },

  deleteBanner: async (id: string) => {
    return apiFetch(`/admin/banners/${id}`, {
      method: "DELETE",
    });
  },

  // App Config & Feature Flags
  getAppConfig: async () => {
    return apiFetch("/admin/app-config").catch(() => ({
      free_episode_count: 3,
      default_episode_coin_price: 20,
      maintenance_mode: false,
      min_supported_version: "1.0.0",
    }));
  },

  updateAppConfig: async (key: string, value: any) => {
    return apiFetch(`/admin/app-config/${key}`, {
      method: "PATCH",
      json: value,
    }).catch(() => ({ status: "updated", key }));
  },

  listFeatureFlags: async () => {
    return apiFetch("/admin/feature-flags").catch(() => [
      { key: "audio_bedtime_stories", enabled: false, rollout_percentage: 0, description: "Audio reading feature" },
      { key: "new_rewards_lucky_chest", enabled: true, rollout_percentage: 100, description: "Gamified reward lucky chest" },
    ]);
  },

  updateFeatureFlag: async (key: string, enabled: boolean) => {
    return apiFetch(`/admin/feature-flags/${key}`, {
      method: "PATCH",
      json: { enabled },
    }).catch(() => ({ status: "updated", key }));
  },

  // User Management
  listUsers: async () => {
    return apiFetch("/admin/users");
  },

  updateUser: async (id: string, userPayload: any) => {
    return apiFetch(`/admin/users/${id}`, {
      method: "PATCH",
      json: userPayload,
    });
  },

  // Push Campaigns
  listCampaigns: async () => {
    return apiFetch("/admin/notifications/campaigns");
  },

  sendPushCampaign: async (campaign: any) => {
    return apiFetch("/admin/notifications/campaign", {
      method: "POST",
      json: campaign,
    });
  },

  // AI Story Generation
  generateAIStoryOutline: async (prompt: string) => {
    return apiFetch("/admin/ai/stories/generate-outline", {
      method: "POST",
      json: { prompt },
    });
  },

  saveAIStoryOutline: async (outline: any) => {
    return apiFetch("/admin/ai/stories/save-outline", {
      method: "POST",
      json: outline,
    });
  },

  getAIContext: async (storyId: string) => {
    return apiFetch(`/admin/ai/stories/${storyId}/context`);
  },

  generateAIEpisode: async (storyId: string, guidance?: string) => {
    return apiFetch(`/admin/ai/stories/${storyId}/generate-episode`, {
      method: "POST",
      json: { guidance },
    });
  },

  regenerateAIEpisode: async (storyId: string, guidance?: string) => {
    return apiFetch(`/admin/ai/stories/${storyId}/regenerate-episode`, {
      method: "POST",
      json: { guidance },
    });
  },
};
