import { Navigation } from '@/components/navigation';

export default function DashboardLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <div className="flex flex-col md:flex-row h-screen w-full overflow-hidden bg-background">
      <Navigation />
      <main className="flex-1 h-full overflow-y-auto p-4 md:p-8 max-w-7xl mx-auto w-full">
        {children}
      </main>
    </div>
  );
}
