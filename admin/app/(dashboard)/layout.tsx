"use client";

import { useEffect, useState } from "react";
import { useRouter, usePathname } from "next/navigation";
import Link from "next/link";
import { getAuthToken, removeAuthToken, api } from "../lib/api";
import {
  LayoutDashboard,
  BookOpen,
  Image as ImageIcon,
  Settings,
  LogOut,
  Moon,
  Loader2,
  Menu,
  X,
  User,
  Bell,
} from "lucide-react";

export default function DashboardLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  const router = useRouter();
  const pathname = usePathname();
  const [loading, setLoading] = useState(true);
  const [admin, setAdmin] = useState<any>(null);
  const [mobileMenuOpen, setMobileMenuOpen] = useState(false);

  useEffect(() => {
    const token = getAuthToken();
    if (!token) {
      router.push("/login");
      return;
    }

    api.getCurrentAdmin()
      .then((res) => {
        setAdmin(res);
        setLoading(false);
      })
      .catch(() => {
        removeAuthToken();
        router.push("/login");
      });
  }, [router]);

  const handleSignOut = () => {
    removeAuthToken();
    router.push("/login");
  };

  if (loading) {
    return (
      <div className="flex min-h-screen items-center justify-center bg-[#050816] text-[#8b5cf6]">
        <Loader2 className="h-10 w-10 animate-spin" />
      </div>
    );
  }

  const navItems = [
    { name: "Dashboard", href: "/", icon: LayoutDashboard },
    { name: "Stories & CMS", href: "/stories", icon: BookOpen },
    { name: "Banner Ads", href: "/banners", icon: ImageIcon },
    { name: "Users & Profiles", href: "/users", icon: User },
    { name: "Push Campaigns", href: "/notifications", icon: Bell },
    { name: "App Settings", href: "/config", icon: Settings },
  ];

  return (
    <div className="flex h-screen bg-[#050816] text-slate-100 overflow-hidden">
      {/* Sidebar - Desktop */}
      <aside className="hidden md:flex md:w-64 md:flex-col bg-[#101426] border-r border-[#2d334a]">
        <div className="flex h-16 items-center px-6 border-b border-[#2d334a] gap-2">
          <Moon className="h-6 w-6 text-[#8b5cf6]" />
          <span className="font-bold text-lg tracking-wider bg-gradient-to-r from-purple-400 to-indigo-300 bg-clip-text text-transparent">
            MOONLIT ADMIN
          </span>
        </div>

        <nav className="flex-1 space-y-1 px-4 py-6">
          {navItems.map((item) => {
            const isActive = pathname === item.href || (item.href !== "/" && pathname.startsWith(item.href));
            return (
              <Link
                key={item.name}
                href={item.href}
                className={`flex items-center px-4 py-3 text-sm font-medium rounded-lg transition-colors gap-3 ${
                  isActive
                    ? "bg-[#8b5cf6]/10 text-[#8b5cf6] border-l-4 border-[#8b5cf6]"
                    : "text-[#94a3b8] hover:bg-[#171b31] hover:text-white"
                }`}
              >
                <item.icon className="h-5 w-5" />
                {item.name}
              </Link>
            );
          })}
        </nav>

        <div className="p-4 border-t border-[#2d334a] bg-[#0c0f1e]">
          <div className="flex items-center gap-3 px-2 py-1 mb-3">
            <div className="flex h-9 w-9 items-center justify-center rounded-full bg-purple-500/20 text-[#8b5cf6]">
              <User className="h-5 w-5" />
            </div>
            <div className="overflow-hidden">
              <p className="text-xs text-[#94a3b8] truncate">Admin Account</p>
              <p className="text-sm font-semibold truncate">{admin?.id ? "System Admin" : "Editor"}</p>
            </div>
          </div>
          <button
            onClick={handleSignOut}
            className="flex w-full items-center justify-center px-4 py-2.5 text-sm font-medium text-red-400 hover:bg-red-950/20 hover:text-red-300 rounded-lg transition-colors border border-red-500/20 gap-2"
          >
            <LogOut className="h-4 w-4" />
            Sign Out
          </button>
        </div>
      </aside>

      {/* Main Container */}
      <div className="flex flex-col flex-1 overflow-hidden">
        {/* Top Header */}
        <header className="flex h-16 items-center justify-between px-6 bg-[#101426] border-b border-[#2d334a]">
          <button
            onClick={() => setMobileMenuOpen(true)}
            className="md:hidden text-[#94a3b8] hover:text-white"
          >
            <Menu className="h-6 w-6" />
          </button>

          <div className="hidden md:block">
            <h1 className="text-md text-[#94a3b8]">Welcome back, Admin.</h1>
          </div>

          <div className="flex items-center gap-4">
            <div className="flex items-center gap-1.5 px-3 py-1.5 text-xs font-semibold uppercase tracking-wider rounded-full bg-emerald-500/10 text-emerald-400 border border-emerald-500/20">
              <span className="h-2 w-2 rounded-full bg-emerald-500 animate-ping" />
              API Connected
            </div>
          </div>
        </header>

        {/* Content Area */}
        <main className="flex-1 overflow-y-auto p-6 md:p-8 bg-[#050816]">
          {children}
        </main>
      </div>

      {/* Mobile Menu Backdrop */}
      {mobileMenuOpen && (
        <div
          className="fixed inset-0 z-40 bg-black/60 md:hidden"
          onClick={() => setMobileMenuOpen(false)}
        />
      )}

      {/* Mobile Sidebar drawer */}
      <div
        className={`fixed inset-y-0 left-0 z-50 w-64 bg-[#101426] border-r border-[#2d334a] transform transition-transform duration-300 md:hidden flex flex-col ${
          mobileMenuOpen ? "translate-x-0" : "-translate-x-full"
        }`}
      >
        <div className="flex h-16 items-center justify-between px-6 border-b border-[#2d334a]">
          <div className="flex items-center gap-2">
            <Moon className="h-6 w-6 text-[#8b5cf6]" />
            <span className="font-bold text-md tracking-wider">MOONLIT ADMIN</span>
          </div>
          <button
            onClick={() => setMobileMenuOpen(false)}
            className="text-[#94a3b8] hover:text-white"
          >
            <X className="h-6 w-6" />
          </button>
        </div>

        <nav className="flex-1 space-y-1 px-4 py-6" onClick={() => setMobileMenuOpen(false)}>
          {navItems.map((item) => {
            const isActive = pathname === item.href || (item.href !== "/" && pathname.startsWith(item.href));
            return (
              <Link
                key={item.name}
                href={item.href}
                className={`flex items-center px-4 py-3 text-sm font-medium rounded-lg gap-3 ${
                  isActive
                    ? "bg-[#8b5cf6]/10 text-[#8b5cf6]"
                    : "text-[#94a3b8] hover:bg-[#171b31] hover:text-white"
                }`}
              >
                <item.icon className="h-5 w-5" />
                {item.name}
              </Link>
            );
          })}
        </nav>

        <div className="p-4 border-t border-[#2d334a]" onClick={() => setMobileMenuOpen(false)}>
          <button
            onClick={handleSignOut}
            className="flex w-full items-center justify-center px-4 py-2.5 text-sm font-medium text-red-400 hover:bg-red-950/20 rounded-lg transition-colors border border-red-500/20 gap-2"
          >
            <LogOut className="h-4 w-4" />
            Sign Out
          </button>
        </div>
      </div>
    </div>
  );
}
