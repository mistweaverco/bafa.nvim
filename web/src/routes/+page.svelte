<script lang="ts">
	import HeadComponent from "$lib/HeadComponent.svelte";
	const GH_BASE_URL = "https://github.com/mistweaverco/bafa.nvim/";

	const handleAnchorClick = (evt: Event) => {
		evt.preventDefault();
		const link = evt.currentTarget as HTMLAnchorElement;
		const anchorId = new URL(link.href).hash.replace("#", "");
		const anchor = document.getElementById(anchorId);
		window.scrollTo({
			top: anchor?.offsetTop,
			behavior: "smooth",
		});
	};
	const preventGalleryJump = (evt: Event) => {
		evt.preventDefault();
		const link = evt.currentTarget as HTMLAnchorElement;
		const anchorId = new URL(link.href).hash.replace("#", "");
		if (!anchorId) return;
		// if starts with slide, prevent horizontal jump
		if (anchorId.startsWith("slide")) {
			const currentScroll = window.scrollY;
			const anchor = document.getElementById(anchorId);
			anchor?.scrollIntoView({ behavior: "smooth" });
			window.scrollTo({ top: currentScroll });
		}
	};
	interface Screenshot {
		src: string;
		alt: string;
		title: string;
		text: string;
		ghLink?: {
			slug: string;
			text: string;
		};
	}
	const screenshots: Screenshot[] = [
		{
			src: "/assets/screenshots/default-ui.png",
			alt: "The default bafa.nvim UI showing a list of buffers.",
			title: "Default UI",
			text: "The default bafa.nvim UI showing a list of buffers with icons, modified and marked for deletion indicators.",
		},
		{
			src: "/assets/screenshots/jump-labels.png",
			alt: "The bafa.nvim UI showing jump labels for each buffer.",
			title: "Jump Labels",
			text: "The bafa.nvim UI showing jump labels for each buffer, allowing quick navigation using assigned keys.",
		},
		{
			src: "/assets/screenshots/jump-labels-delete.png",
			alt: "The bafa.nvim UI showing jump labels for each buffer with delete labels.",
			title: "Jump Labels - Mark for deletion",
			text: "The bafa.nvim UI showing jump labels for each buffer with delete labels, allowing quick marking of buffers for deletion.",
		},
		{
			src: "/assets/screenshots/marked-for-deletion-signs.png",
			alt: "The bafa.nvim UI showing buffers marked for deletion.",
			title: "Marked for Deletion Signs",
			text: "The bafa.nvim UI showing buffers marked for deletion with a distinct indicator.",
		},
		{
			src: "/assets/screenshots/modified-signs.png",
			alt: "The bafa.nvim UI showing modified buffers.",
			title: "Modified Signs",
			text: "The bafa.nvim UI showing modified buffers with a distinct indicator.",
		},
	];
</script>

<HeadComponent
	data={{
		title: "bafa.nvim",
		description: "A minimal BufExplorer alternative for lazy people for your favorite editor.",
	}}
/>

<div id="start" class="hero bg-base-200 min-h-screen">
	<div class="hero-content text-center">
		<div class="max-w-md">
			<img src="/logo.svg" alt="bafa.nvim logo" class="m-5 mx-auto w-64" />
			<h1 class="text-5xl font-bold">bafa.nvim</h1>
			<p class="py-6">A minimal BufExplorer alternative for lazy people for your favorite editor.</p>
			<a href="#screenshots" on:click={handleAnchorClick}><button class="btn btn-primary">Screenshots</button></a>
		</div>
	</div>
</div>
<div id="screenshots" class="bg-base-200 min-h-screen flex flex-col justify-center">
	<div class="text-center mb-10">
		<h1 class="text-5xl font-bold">Screenshots 📸</h1>
		<p class="pt-6">Some screenshots</p>
	</div>
	<div class="text-center mb-10 w-full max-w-4xl mx-auto carousel carousel-center space-x-4 rounded-box">
		{#each screenshots as image, index (index)}
			<div id={"slide" + (index + 1)} class="carousel-item relative w-full">
				<div class="card bg-base-100 shadow-xl">
					<figure>
						<img src={image.src} alt={image.alt} class="w-full object-contain" />
					</figure>
					<div class="card-body">
						<h2 class="card-title justify-center">{image.title}</h2>
						<p>{image.text}</p>
						{#if image.ghLink}
							<div class="card-actions justify-end mt-4">
								<a href={GH_BASE_URL + image.ghLink.slug} target="_blank" rel="noopener noreferrer">
									<button class="btn btn-block">{image.ghLink.text}</button>
								</a>
							</div>
						{/if}
					</div>
					<div class="absolute left-5 right-5 top-1/2 flex -translate-y-1/2 transform justify-between">
						{#if index !== 0}
						<a
							on:click={preventGalleryJump}
							href={"#slide" + (index)}
							class="btn btn-circle">❮</a
						>
						{:else}
							<div></div>
						{/if}
						{#if index !== screenshots.length - 1}
							<a
								on:click={preventGalleryJump}
								href={"#slide" +  (index + 2)}
								class="btn btn-circle">❯</a
							>
						{:else}
							<div></div>
						{/if}
					</div>
				</div>
			</div>
		{/each}
	</div>
	<div class="text-center">
		<p>
			<a href="#get-involved" on:click={handleAnchorClick}
				><button class="btn btn-secondary mt-5">Get involved</button></a
			>
		</p>
	</div>
</div>
<div id="get-involved" class="hero bg-base-200 min-h-screen">
	<div class="hero-content text-center">
		<div class="max-w-md">
			<h1 class="text-5xl font-bold">Get involved ❤️</h1>
			<p class="py-6">bafa.nvim is open-source and we welcome contributions.</p>
			<p>
				View the <a class="text-secondary" href="https://github.com/mistweaverco/bafa.nvim">code.</a>
			</p>
		</div>
	</div>
</div>
