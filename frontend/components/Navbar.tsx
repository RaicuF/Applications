'use client'

import { Shield, User, Settings, LogOut } from 'lucide-react'
import { useState } from 'react'

export default function Navbar() {
  const [isUserMenuOpen, setIsUserMenuOpen] = useState(false)

  return (
    <nav className="bg-dark-900/50 backdrop-blur-md border-b border-dark-700">
      <div className="container mx-auto px-4">
        <div className="flex items-center justify-between h-16">
          <div className="flex items-center gap-3">
            <Shield className="w-8 h-8 text-primary-400" />
            <span className="text-xl font-bold text-white">LogAnalyzer Pro</span>
          </div>

          <div className="flex items-center gap-6">
            <button className="text-gray-300 hover:text-white transition-colors">
              Documentation
            </button>
            <button className="text-gray-300 hover:text-white transition-colors">
              Pricing
            </button>
            
            <div className="relative">
              <button
                onClick={() => setIsUserMenuOpen(!isUserMenuOpen)}
                className="flex items-center gap-2 px-4 py-2 rounded-lg bg-primary-600 hover:bg-primary-700 text-white transition-colors"
              >
                <User className="w-5 h-5" />
                <span>Account</span>
              </button>

              {isUserMenuOpen && (
                <div className="absolute right-0 mt-2 w-48 bg-dark-800 rounded-lg shadow-xl border border-dark-700">
                  <button className="flex items-center gap-2 w-full px-4 py-2 text-gray-300 hover:bg-dark-700 hover:text-white">
                    <Settings className="w-4 h-4" />
                    Settings
                  </button>
                  <button className="flex items-center gap-2 w-full px-4 py-2 text-gray-300 hover:bg-dark-700 hover:text-white">
                    <LogOut className="w-4 h-4" />
                    Logout
                  </button>
                </div>
              )}
            </div>
          </div>
        </div>
      </div>
    </nav>
  )
}