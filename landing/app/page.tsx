import { ArchitectureDiagram } from "@/components/ArchitectureDiagram";
import { FooterBar, TopBar } from "@/components/Chrome";
import { Features } from "@/components/Features";
import { Hero } from "@/components/Hero";
import { ValidatedProblem } from "@/components/ValidatedProblem";
import { WhyWeWin } from "@/components/WhyWeWin";

export default function Home() {
  return (
    <>
      <TopBar />
      <main className="flex-1">
        <Hero />
        <ValidatedProblem />
        <Features />
        <ArchitectureDiagram />
        <WhyWeWin />
      </main>
      <FooterBar />
    </>
  );
}
