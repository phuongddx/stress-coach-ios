// Landing page assembly. S1–S7 (nav, hero, trust, score, coach, ripple, calm)
// land here; S8–S14 arrive in the next task. The shared scroll-reveal is a
// pure-CSS view() timeline: elements sit hidden only in browsers that support
// scroll-driven animations (where they animate in on entry), and render in
// their final state everywhere else and under prefers-reduced-motion.
import { Nav } from "@/components/landing/Nav";
import { Hero } from "@/components/landing/Hero";
import { TrustStrip } from "@/components/landing/TrustStrip";
import { ScoreSection } from "@/components/landing/ScoreSection";
import { CoachSection } from "@/components/landing/CoachSection";
import { RippleSection } from "@/components/landing/RippleSection";
import { CalmSection } from "@/components/landing/CalmSection";

const PAGE_CSS = `
@supports (animation-timeline: view()){
  [data-reveal]{
    animation:sac-reveal-in .74s linear both;
    animation-timeline:view();
    animation-range:entry 0% entry 70%;
  }
}
@keyframes sac-reveal-in{
  from{opacity:0;transform:translateY(26px)}
  to{opacity:1;transform:none}
}
@media (prefers-reduced-motion: reduce){
  [data-reveal]{animation:none!important;opacity:1!important;transform:none!important}
}
`;

export default function Page() {
  return (
    <main id="top" className="sac-page">
      <style href="sac-page" precedence="default">{PAGE_CSS}</style>
      <Nav />
      <Hero />
      <TrustStrip />
      <ScoreSection />
      <CoachSection />
      <RippleSection />
      <CalmSection />
    </main>
  );
}
