/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,
  transpilePackages: ['@nocta/design-tokens'],
  // W0'da output: 'export' (SSG) + Cloudflare Pages hedefi (docs/05 §2).
};

export default nextConfig;
