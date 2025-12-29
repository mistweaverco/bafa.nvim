import tailwindcss from "@tailwindcss/vite";
import adapter from "@sveltejs/adapter-static";

/** @type {import('@sveltejs/kit').Config} */
const config = {
  kit: {
    adapter: adapter(),
  },
  extensions: [".svelte"],
  plugins: [tailwindcss()],
};

export default config;
