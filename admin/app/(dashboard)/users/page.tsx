"use client";

import { useEffect, useState } from "react";
import { api } from "../../lib/api";
import { Users, ShieldAlert, Award, CircleDollarSign, ShieldCheck, Edit, Search, X } from "lucide-react";

export default function UsersPage() {
  const [users, setUsers] = useState<any[]>([]);
  const [search, setSearch] = useState("");
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [success, setSuccess] = useState("");
  
  // Modal states
  const [selectedUser, setSelectedUser] = useState<any>(null);
  const [editStatus, setEditStatus] = useState("");
  const [editLevel, setEditLevel] = useState(1);
  const [editDisplayName, setEditDisplayName] = useState("");
  const [grantCoinsAmount, setGrantCoinsAmount] = useState(0);
  const [updating, setUpdating] = useState(false);

  const fetchUsers = async () => {
    try {
      const data = await api.listUsers();
      setUsers(data);
    } catch (err: any) {
      setError(err.message || "Failed to retrieve users list");
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchUsers();
  }, []);

  const openEditModal = (user: any) => {
    setSelectedUser(user);
    setEditStatus(user.status);
    setEditLevel(user.level);
    setEditDisplayName(user.display_name || "");
    setGrantCoinsAmount(0);
  };

  const closeEditModal = () => {
    setSelectedUser(null);
  };

  const handleUpdateUser = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!selectedUser) return;
    
    setUpdating(true);
    setError("");
    setSuccess("");

    try {
      const payload: any = {
        status: editStatus,
        level: Number(editLevel),
        display_name: editDisplayName,
      };
      
      if (grantCoinsAmount !== 0) {
        payload.grant_coins = Number(grantCoinsAmount);
      }

      await api.updateUser(selectedUser.id, payload);
      setSuccess(`User details updated successfully!`);
      closeEditModal();
      fetchUsers();
    } catch (err: any) {
      setError(err.message || "Failed to update user profile");
    } finally {
      setUpdating(false);
    }
  };

  const filteredUsers = users.filter((u) => {
    const q = search.toLowerCase();
    return (
      u.id.toLowerCase().includes(q) ||
      (u.email && u.email.toLowerCase().includes(q)) ||
      (u.username && u.username.toLowerCase().includes(q)) ||
      (u.display_name && u.display_name.toLowerCase().includes(q))
    );
  });

  if (loading) {
    return (
      <div className="flex h-64 items-center justify-center text-[#8b5cf6]">
        <Users className="h-8 w-8 animate-spin" />
      </div>
    );
  }

  return (
    <div className="space-y-6">
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
        <div>
          <h2 className="text-3xl font-bold tracking-tight text-white">Users & Profiles</h2>
          <p className="text-sm text-[#94a3b8]">
            Manage user accounts, ban violating guest accounts, audit wallets, and grant coin rewards
          </p>
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

      {/* Toolbar */}
      <div className="flex items-center gap-3 bg-[#101426] border border-[#2d334a] p-4 rounded-xl">
        <Search className="h-5 w-5 text-[#94a3b8]" />
        <input
          type="text"
          placeholder="Search users by ID, Email, Username, or Display Name..."
          value={search}
          onChange={(e) => setSearch(e.target.value)}
          className="w-full bg-transparent text-sm text-white focus:outline-none placeholder-[#64748b]"
        />
      </div>

      {/* Users Table */}
      <div className="rounded-xl border border-[#2d334a] bg-[#101426] overflow-hidden shadow-md">
        <div className="overflow-x-auto">
          <table className="w-full text-left text-sm text-slate-300">
            <thead className="bg-[#171b31] text-xs font-semibold uppercase tracking-wider text-[#94a3b8] border-b border-[#2d334a]">
              <tr>
                <th className="py-4 px-6">User Profile</th>
                <th className="py-4 px-6">Account Status</th>
                <th className="py-4 px-6">Level</th>
                <th className="py-4 px-6">Wallet Balance</th>
                <th className="py-4 px-6">Joined Date</th>
                <th className="py-4 px-6 text-right">Actions</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-[#2d334a]/60">
              {filteredUsers.map((user) => (
                <tr key={user.id} className="hover:bg-[#151a35]/30 transition-colors">
                  <td className="py-4 px-6">
                    <div>
                      <p className="font-bold text-white text-sm">{user.display_name || user.username || "Guest User"}</p>
                      <p className="text-xs text-[#94a3b8] mt-0.5">{user.email || "No email linked"}</p>
                      <p className="text-[10px] font-mono text-[#64748b] mt-1">{user.id}</p>
                    </div>
                  </td>
                  <td className="py-4 px-6">
                    {user.status === "banned" ? (
                      <span className="inline-flex items-center gap-1.5 rounded-full bg-red-500/10 border border-red-500/20 px-2.5 py-1 text-xs font-semibold text-red-400">
                        <ShieldAlert className="h-3 w-3" />
                        Banned
                      </span>
                    ) : (
                      <span className="inline-flex items-center gap-1.5 rounded-full bg-emerald-500/10 border border-emerald-500/20 px-2.5 py-1 text-xs font-semibold text-emerald-400">
                        <ShieldCheck className="h-3 w-3" />
                        Active
                      </span>
                    )}
                  </td>
                  <td className="py-4 px-6 font-semibold">
                    <span className="inline-flex items-center gap-1 text-xs bg-purple-500/10 text-purple-400 border border-purple-500/20 px-2.5 py-0.5 rounded-full">
                      Lvl {user.level}
                    </span>
                  </td>
                  <td className="py-4 px-6">
                    <div className="space-y-1">
                      <p className="text-xs text-amber-400 font-bold flex items-center gap-1">
                        <CircleDollarSign className="h-3.5 w-3.5" />
                        {user.coins} Coins
                      </p>
                      <p className="text-[10px] text-slate-400">
                        {user.gems} Gems · {user.free_pass} Passes
                      </p>
                    </div>
                  </td>
                  <td className="py-4 px-6 text-xs text-[#94a3b8]">
                    {new Date(user.created_at).toLocaleDateString()}
                  </td>
                  <td className="py-4 px-6 text-right">
                    <button
                      onClick={() => openEditModal(user)}
                      className="rounded-lg border border-[#2d334a] hover:border-[#8b5cf6] hover:text-[#8b5cf6] p-2 transition-colors inline-flex items-center gap-1.5 text-xs font-semibold"
                    >
                      <Edit className="h-3.5 w-3.5" />
                      Manage
                    </button>
                  </td>
                </tr>
              ))}

              {filteredUsers.length === 0 && (
                <tr>
                  <td colSpan={6} className="text-center py-8 text-[#94a3b8] text-xs">
                    No users matching search query
                  </td>
                </tr>
              )}
            </tbody>
          </table>
        </div>
      </div>

      {/* Edit User Modal */}
      {selectedUser && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/60 backdrop-blur-xs">
          <div className="w-full max-w-md rounded-2xl border border-[#2d334a] bg-[#101426] p-6 shadow-2xl space-y-6 text-sm text-slate-300">
            <div className="flex items-center justify-between border-b border-[#2d334a] pb-4">
              <div>
                <h3 className="text-lg font-bold text-white">Manage User Account</h3>
                <p className="text-xs text-[#94a3b8] font-mono mt-0.5">{selectedUser.id}</p>
              </div>
              <button onClick={closeEditModal} className="text-slate-400 hover:text-white">
                <X className="h-5 w-5" />
              </button>
            </div>

            <form onSubmit={handleUpdateUser} className="space-y-4">
              <div>
                <label className="block text-xs font-semibold uppercase tracking-wider text-[#94a3b8] mb-1.5">
                  Display Name
                </label>
                <input
                  type="text"
                  value={editDisplayName}
                  onChange={(e) => setEditDisplayName(e.target.value)}
                  className="block w-full rounded-lg border border-[#2d334a] bg-[#171b31] py-2 px-3 text-white focus:border-[#8b5cf6] focus:outline-none"
                />
              </div>

              <div className="grid grid-cols-2 gap-4">
                <div>
                  <label className="block text-xs font-semibold uppercase tracking-wider text-[#94a3b8] mb-1.5">
                    Account Status
                  </label>
                  <select
                    value={editStatus}
                    onChange={(e) => setEditStatus(e.target.value)}
                    className="block w-full rounded-lg border border-[#2d334a] bg-[#171b31] py-2 px-3 text-white focus:border-[#8b5cf6] focus:outline-none"
                  >
                    <option value="active">Active</option>
                    <option value="banned">Banned</option>
                  </select>
                </div>

                <div>
                  <label className="block text-xs font-semibold uppercase tracking-wider text-[#94a3b8] mb-1.5">
                    User Level
                  </label>
                  <input
                    type="number"
                    min="1"
                    value={editLevel}
                    onChange={(e) => setEditLevel(Number(e.target.value))}
                    className="block w-full rounded-lg border border-[#2d334a] bg-[#171b31] py-2 px-3 text-white focus:border-[#8b5cf6] focus:outline-none"
                  />
                </div>
              </div>

              <div className="border-t border-[#2d334a]/60 pt-4">
                <h4 className="text-xs font-bold uppercase tracking-wider text-[#94a3b8] mb-2 flex items-center gap-1">
                  <Award className="h-4 w-4 text-amber-500" />
                  Grant Coins
                </h4>
                <div className="flex items-center gap-3">
                  <input
                    type="number"
                    placeholder="E.g. 500 or -200"
                    value={grantCoinsAmount || ""}
                    onChange={(e) => setGrantCoinsAmount(Number(e.target.value))}
                    className="block w-full rounded-lg border border-[#2d334a] bg-[#171b31] py-2 px-3 text-white focus:border-[#8b5cf6] focus:outline-none text-sm"
                  />
                  <span className="text-xs text-[#94a3b8] whitespace-nowrap">
                    Current: <strong>{selectedUser.coins}</strong>
                  </span>
                </div>
                <p className="text-[11px] text-[#94a3b8] mt-1.5">
                  Positive values grant coins. Negative values deduct coins.
                </p>
              </div>

              <div className="border-t border-[#2d334a] pt-4 flex gap-3">
                <button
                  type="button"
                  onClick={closeEditModal}
                  className="flex-1 rounded-lg border border-[#2d334a] hover:bg-[#171b31] py-2.5 font-semibold text-white transition-colors"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  disabled={updating}
                  className="flex-1 rounded-lg bg-[#8b5cf6] hover:bg-[#7c3aed] py-2.5 font-semibold text-white transition-colors"
                >
                  {updating ? "Saving Changes..." : "Save Settings"}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}
