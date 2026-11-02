import type { Config } from 'tailwindcss';

const config: Config = {
  darkMode: 'class',
  content: [
    './src/pages/**/*.{js,ts,jsx,tsx,mdx}',
    './src/components/**/*.{js,ts,jsx,tsx,mdx}',
    './src/app/**/*.{js,ts,jsx,tsx,mdx}',
  ],
  theme: {
    extend: {
      colors: {
        background: 'var(--background)',
        foreground: 'var(--foreground)',
        card: 'var(--card)',
        'card-foreground': 'var(--card-foreground)',
        subtle: 'var(--subtle)',
        border: 'var(--border)',
        primary: {
          DEFAULT: 'var(--primary)',
          foreground: 'var(--primary-foreground)',
          subtle: 'var(--primary-subtle)',
        },
        muted: {
          DEFAULT: 'var(--muted)',
          foreground: 'var(--muted-foreground)',
        },
        income: {
          DEFAULT: 'var(--income)',
          subtle: 'var(--income-subtle)',
          border: 'var(--income-border)',
        },
        expense: {
          DEFAULT: 'var(--expense)',
          subtle: 'var(--expense-subtle)',
          border: 'var(--expense-border)',
        },
        warning: {
          DEFAULT: 'var(--warning)',
          subtle: 'var(--warning-subtle)',
          border: 'var(--warning-border)',
        },
      },
      borderRadius: {
        sm: '6px',
        md: '8px',
        lg: '12px',
      },
      boxShadow: {
        card: '0 1px 2px 0 rgba(15, 23, 42, 0.04)',
      },
      transitionDuration: {
        DEFAULT: '150ms',
        fast: '150ms',
        normal: '200ms',
      },
    },
  },
  plugins: [],
};

export default config;
