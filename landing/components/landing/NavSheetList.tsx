"use client";

// The mobile nav sheet's link list (client so a tap can close the sheet).
// Anchor navigation proceeds natively; the click handler just unchecks the
// checkbox driving the sheet — matching the design's JS, which collapsed the
// sheet on link tap — so the open sheet doesn't sit over the section the user
// just scrolled to. Keyboard activation (Enter on a link) fires a bubbling
// click, so it is covered too.
export function NavSheetList({ links }: { links: ReadonlyArray<readonly [string, string]> }) {
  return (
    <ul
      role="list"
      className="grid gap-0.5 px-[clamp(20px,5vw,40px)] pt-2 pb-[18px]"
      onClick={(event) => {
        if (!(event.target instanceof Element) || !event.target.closest("a")) return;
        const box = document.getElementById("sac-nav-toggle") as HTMLInputElement | null;
        if (box?.checked) box.checked = false;
      }}
    >
      {links.map(([label, href]) => (
        <li key={href}>
          <a
            href={href}
            className="flex min-h-[48px] items-center border-b border-ink/[0.06] px-1 text-[1.0625rem] font-medium text-ink no-underline"
          >
            {label}
          </a>
        </li>
      ))}
    </ul>
  );
}
