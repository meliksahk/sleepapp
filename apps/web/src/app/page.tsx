import { WaitlistForm } from '@/components/WaitlistForm';

export default function HomePage() {
  return (
    <main className="mx-auto max-w-2xl p-5">
      <h1 className="text-display font-display">Your night has an identity.</h1>
      <p className="mt-3 text-body text-ink-secondary">
        NOCTA is a sleep ritual app. Discover your sleep identity, then build a night that fits it.
      </p>
      <a
        href="/test"
        className="mt-5 inline-block rounded-button bg-accent-aurora px-5 py-3 text-bg-base"
      >
        Find your sleep identity
      </a>

      <section className="mt-10">
        <h2 className="text-h2 font-display">Join the waitlist</h2>
        <p className="mt-2 mb-3 text-body text-ink-secondary">
          Be first to know when NOCTA launches.
        </p>
        <WaitlistForm />
      </section>
    </main>
  );
}
