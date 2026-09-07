// "Meet Ripple", ported from sac-landing §6. Task 3's CharacterRow renders a
// wrapping grid; this section re-scopes it to the design's rail geometry via
// a descendant selector (higher specificity than the row's single utility
// classes): a full-bleed scroll-snap carousel below 1100px, the design's flat
// five-column row at ≥1100px. The design's prev/next arrows are omitted —
// they scroll via JS, and native snap scrolling covers the interaction
// without a hydration island on a static page.
import { CharacterRow } from "@/components/illustrations/CharacterRow";
import { SectionHeading } from "@/components/SectionHeading";

const RAIL_CSS = `
.sac-rail>ul{
  grid-template-columns:none;
  grid-auto-flow:column;
  grid-auto-columns:minmax(232px,1fr);
  overflow-x:auto;
  scroll-snap-type:x mandatory;
  padding:6px clamp(20px,5vw,40px) 24px;
  margin-inline:calc(clamp(20px,5vw,40px)*-1);
  scrollbar-width:none;
}
.sac-rail>ul::-webkit-scrollbar{display:none}
.sac-rail>ul>li{scroll-snap-align:start}
@media (min-width:1100px){
  .sac-rail>ul{
    grid-auto-flow:row;
    grid-auto-columns:auto;
    grid-template-columns:repeat(5,minmax(0,1fr));
    overflow:visible;
    padding-inline:0;
    margin-inline:0;
  }
}
`;

export function RippleSection() {
  return (
    <section id="ripple" className="bg-surface py-[clamp(72px,9vw,132px)]">
      <div className="mx-auto w-full max-w-[1180px] px-[clamp(20px,5vw,40px)]">
        <div data-reveal className="mb-[30px]">
          <SectionHeading
            eyebrow="The companion"
            title="Meet Ripple"
            lede="A small water-drop creature that reflects how your body actually feels. Ripple slumps on your hard days, brightens on your calm ones, and grows as you keep taking care of yourself. Four more companions unlock along the way."
          />
        </div>
        <style href="sac-rail" precedence="default">{RAIL_CSS}</style>
        <div data-reveal className="sac-rail">
          <CharacterRow />
        </div>
      </div>
    </section>
  );
}
