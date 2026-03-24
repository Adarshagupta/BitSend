(function () {
  const root = document.documentElement;
  root.classList.add("js");

  const config = window.BITSEND_CONFIG || {};
  const appTargetUrl = config.APP_TARGET_URL || "/app/";
  const prefersReducedMotion = window.matchMedia(
    "(prefers-reduced-motion: reduce)",
  );

  const appLinks = document.querySelectorAll("[data-app-link]");
  const main = document.getElementById("main");
  const sections = Array.from(document.querySelectorAll("[data-section]"));
  const navLinks = Array.from(document.querySelectorAll("[data-nav-link]"));
  const siteHeader = document.querySelector(".site-header");
  const siteNav = document.getElementById("site-nav");
  const menuToggle = document.querySelector("[data-menu-toggle]");
  const tiltStage = document.querySelector("[data-tilt-stage]");
  const flowSection = document.getElementById("flow");
  const flowPin = document.querySelector("[data-flow-pin]");
  const storyStage = document.querySelector(".story-stage");
  const sceneSteps = Array.from(document.querySelectorAll("[data-scene-copy]"));
  const sceneState = document.querySelector("[data-scene-state]");
  const sceneMeter = document.querySelector("[data-scene-meter]");
  const featureShowcase = document.querySelector(".feature-showcase");
  let activeSceneId = null;

  const sceneMeta = {
    1: {
      state: "Looking nearby",
      meter: "Scene 1 / 3",
    },
    2: {
      state: "Sending now",
      meter: "Scene 2 / 3",
    },
    3: {
      state: "Receipt saved",
      meter: "Scene 3 / 3",
    },
  };

  appLinks.forEach((link) => {
    link.setAttribute("href", appTargetUrl);
  });

  const phoneNavMedia = window.matchMedia("(max-width: 520px)");

  const closeMenu = () => {
    if (!siteHeader || !menuToggle) {
      return;
    }

    siteHeader.classList.remove("is-menu-open");
    menuToggle.setAttribute("aria-expanded", "false");
    menuToggle.setAttribute("aria-label", "Open navigation menu");
  };

  const openMenu = () => {
    if (!siteHeader || !menuToggle) {
      return;
    }

    siteHeader.classList.add("is-menu-open");
    menuToggle.setAttribute("aria-expanded", "true");
    menuToggle.setAttribute("aria-label", "Close navigation menu");
  };

  const toggleMenu = () => {
    if (!siteHeader || !menuToggle) {
      return;
    }

    if (siteHeader.classList.contains("is-menu-open")) {
      closeMenu();
      return;
    }

    openMenu();
  };

  if (menuToggle && siteHeader && siteNav) {
    menuToggle.addEventListener("click", toggleMenu);

    navLinks.forEach((link) => {
      link.addEventListener("click", () => {
        if (phoneNavMedia.matches) {
          closeMenu();
        }
      });
    });

    document.addEventListener("click", (event) => {
      if (!phoneNavMedia.matches || !siteHeader.classList.contains("is-menu-open")) {
        return;
      }

      if (siteHeader.contains(event.target)) {
        return;
      }

      closeMenu();
    });

    document.addEventListener("keydown", (event) => {
      if (event.key === "Escape") {
        closeMenu();
      }
    });

    const syncPhoneMenu = (event) => {
      if (!event.matches) {
        closeMenu();
      }
    };

    if (typeof phoneNavMedia.addEventListener === "function") {
      phoneNavMedia.addEventListener("change", syncPhoneMenu);
    } else if (typeof phoneNavMedia.addListener === "function") {
      phoneNavMedia.addListener(syncPhoneMenu);
    }
  }

  const setActiveSection = (id) => {
    navLinks.forEach((link) => {
      const isActive = link.dataset.navLink === id;
      link.classList.toggle("is-active", isActive);
      if (isActive) {
        link.setAttribute("aria-current", "page");
      } else {
        link.removeAttribute("aria-current");
      }
    });
  };

  const setActiveScene = (scene) => {
    const sceneId = String(scene);

    if (activeSceneId === sceneId && storyStage?.dataset.activeScene === sceneId) {
      return;
    }

    activeSceneId = sceneId;

    sceneSteps.forEach((step) => {
      step.classList.toggle("is-active", step.dataset.sceneCopy === sceneId);
    });

    if (storyStage) {
      storyStage.dataset.activeScene = sceneId;
    }

    const meta = sceneMeta[sceneId];
    if (meta && sceneState) {
      if (window.gsap && !prefersReducedMotion.matches) {
        window.gsap.to(sceneState, {
          autoAlpha: 0.35,
          y: -4,
          duration: 0.14,
          overwrite: true,
          onComplete: () => {
            sceneState.textContent = meta.state;
            window.gsap.to(sceneState, {
              autoAlpha: 1,
              y: 0,
              duration: 0.24,
              ease: "power2.out",
            });
          },
        });
      } else {
        sceneState.textContent = meta.state;
      }
    }
    if (meta && sceneMeter) {
      if (window.gsap && !prefersReducedMotion.matches) {
        window.gsap.to(sceneMeter, {
          autoAlpha: 0.35,
          y: -4,
          duration: 0.14,
          overwrite: true,
          onComplete: () => {
            sceneMeter.textContent = meta.meter;
            window.gsap.to(sceneMeter, {
              autoAlpha: 1,
              y: 0,
              duration: 0.24,
              ease: "power2.out",
            });
          },
        });
      } else {
        sceneMeter.textContent = meta.meter;
      }
    }
  };

  const observeSections = () => {
    if (sections.length === 0) {
      return;
    }

    const sectionObserver = new IntersectionObserver(
      (entries) => {
        let bestEntry = null;

        entries.forEach((entry) => {
          if (!entry.isIntersecting) {
            return;
          }
          if (!bestEntry || entry.intersectionRatio > bestEntry.intersectionRatio) {
            bestEntry = entry;
          }
        });

        if (bestEntry) {
          setActiveSection(bestEntry.target.dataset.section);
        }
      },
      {
        threshold: [0.25, 0.45, 0.65, 0.85],
        rootMargin: "-12% 0px -28% 0px",
      },
    );

    sections.forEach((section) => {
      sectionObserver.observe(section);
    });

    setActiveSection(sections[0].dataset.section);
  };

  const setupTiltStage = () => {
    if (!tiltStage || prefersReducedMotion.matches) {
      return;
    }

    const applyTilt = (rotateX, rotateY) => {
      if (window.gsap) {
        window.gsap.to(root, {
          duration: 0.32,
          ease: "power2.out",
          overwrite: true,
          "--hero-stage-rotate-x": `${rotateX}deg`,
          "--hero-stage-rotate-y": `${rotateY}deg`,
        });
        return;
      }

      root.style.setProperty("--hero-stage-rotate-x", `${rotateX}deg`);
      root.style.setProperty("--hero-stage-rotate-y", `${rotateY}deg`);
    };

    const onPointerMove = (event) => {
      const bounds = tiltStage.getBoundingClientRect();
      const x = (event.clientX - bounds.left) / bounds.width;
      const y = (event.clientY - bounds.top) / bounds.height;
      const rotateY = (x - 0.5) * 10;
      const rotateX = (0.5 - y) * 10;

      root.style.setProperty("--stage-light-x", `${(x * 100).toFixed(1)}%`);
      root.style.setProperty("--stage-light-y", `${(y * 100).toFixed(1)}%`);
      applyTilt(rotateX, rotateY);
    };

    const onPointerLeave = () => {
      root.style.setProperty("--stage-light-x", "68%");
      root.style.setProperty("--stage-light-y", "34%");
      applyTilt(0, 0);
    };

    tiltStage.addEventListener("pointermove", onPointerMove);
    tiltStage.addEventListener("pointerleave", onPointerLeave);
  };

  const syncSceneFromProgress = (progress) => {
    if (progress < 0.34) {
      setActiveScene(1);
      return;
    }

    if (progress < 0.72) {
      setActiveScene(2);
      return;
    }

    setActiveScene(3);
  };

  const buildFlowTimeline = () => {
    if (!window.gsap || !storyStage) {
      return null;
    }

    const gsap = window.gsap;
    const timeline = gsap.timeline({
      paused: true,
      defaults: {
        ease: "power2.inOut",
      },
    });

    timeline
      .to(
        ".story-device-left",
        {
          x: -12,
          y: 10,
          rotate: -8,
          duration: 1,
        },
        0,
      )
      .to(
        ".story-device-right",
        {
          x: 14,
          y: -14,
          rotate: 8,
          duration: 1,
        },
        0,
      )
      .to(
        ".story-tower",
        {
          yPercent: -10,
          scaleY: 1.08,
          stagger: 0.03,
          duration: 1.15,
        },
        0,
      )
      .to(
        ".story-layer-1",
        {
          y: -10,
          scale: 1.02,
          duration: 1.1,
        },
        0,
      )
      .to(
        ".story-layer-2",
        {
          y: -14,
          scale: 1.04,
          duration: 1.1,
        },
        0.04,
      )
      .to(
        ".story-layer-3",
        {
          y: -18,
          scale: 1.06,
          duration: 1.1,
        },
        0.08,
      )
      .addLabel("scene2", 1)
      .to(
        ".story-link-line",
        {
          scaleX: 1,
          opacity: 0.95,
          duration: 0.55,
        },
        "scene2",
      )
      .to(
        ".story-link-beam",
        {
          scaleX: 1,
          opacity: 0.9,
          duration: 0.55,
        },
        "scene2+=0.04",
      )
      .to(
        ".story-transfer",
        {
          x: 300,
          y: -12,
          duration: 0.78,
        },
        "scene2+=0.06",
      )
      .to(
        ".story-rings span",
        {
          scale: 1.34,
          opacity: 0.16,
          stagger: 0.04,
          duration: 0.55,
        },
        "scene2",
      )
      .to(
        ".story-device-left",
        {
          x: -22,
          y: 16,
          rotate: -13,
          duration: 0.9,
        },
        "scene2",
      )
      .to(
        ".story-device-right",
        {
          x: 28,
          y: -22,
          rotate: 11,
          duration: 0.9,
        },
        "scene2",
      )
      .addLabel("scene3", 2)
      .to(
        ".story-link-beam",
        {
          opacity: 0.24,
          duration: 0.45,
        },
        "scene3",
      )
      .to(
        ".story-transfer",
        {
          x: 358,
          y: -96,
          scale: 0.82,
          opacity: 0,
          duration: 0.65,
        },
        "scene3",
      )
      .to(
        ".story-chain-ring",
        {
          opacity: 0.8,
          scale: 1.12,
          duration: 0.72,
        },
        "scene3+=0.02",
      )
      .to(
        ".story-receipt",
        {
          y: 0,
          scale: 1,
          opacity: 1,
          duration: 0.68,
        },
        "scene3+=0.1",
      )
      .to(
        ".story-layer-1",
        {
          scale: 1.04,
          duration: 0.8,
        },
        "scene3",
      )
      .to(
        ".story-layer-2",
        {
          scale: 1.08,
          duration: 0.8,
        },
        "scene3+=0.04",
      )
      .to(
        ".story-layer-3",
        {
          scale: 1.12,
          duration: 0.8,
        },
        "scene3+=0.08",
      );

    timeline.progress(0);
    return timeline;
  };

  const resetBackdropMotion = (gsap) => {
    gsap.set(root, {
      "--backdrop-base-x": "0px",
      "--backdrop-base-y": "0px",
      "--backdrop-base-scale": 1,
      "--backdrop-grid-x": "0px",
      "--backdrop-grid-y": "0px",
      "--backdrop-floor-y": "0px",
      "--backdrop-floor-scale": 1,
      "--backdrop-circuit-x": "0px",
      "--backdrop-circuit-y": "0px",
      "--backdrop-circuit-scale": 1,
      "--backdrop-arcs-y": "0px",
      "--backdrop-arc-rotate": "0deg",
      "--backdrop-arc-scale": 1,
      "--backdrop-panel-x": "0px",
      "--backdrop-panel-y": "0px",
      "--backdrop-panel-rotate": "0deg",
      "--backdrop-orb-gold-x": "0px",
      "--backdrop-orb-gold-y": "0px",
      "--backdrop-orb-gold-scale": 1,
      "--backdrop-orb-green-x": "0px",
      "--backdrop-orb-green-y": "0px",
      "--backdrop-orb-green-scale": 1,
      "--hero-backdrop-y": "0px",
      "--hero-backdrop-opacity": 1,
    });
  };

  const buildBackdropTimeline = (gsap, ScrollTrigger, motionScale = 1) => {
    if (!main) {
      return null;
    }

    const px = (value) => `${(value * motionScale).toFixed(1)}px`;
    const deg = (value) => `${(value * motionScale).toFixed(2)}deg`;
    const scale = (value) => (1 + (value - 1) * motionScale).toFixed(3);

    const timeline = gsap.timeline({
      defaults: {
        ease: "none",
      },
      scrollTrigger: {
        trigger: main,
        start: "top top",
        end: "bottom bottom",
        scrub: 0.9,
        invalidateOnRefresh: true,
      },
    });

    timeline
      .to(
        root,
        {
          "--backdrop-base-x": px(8),
          "--backdrop-base-y": px(-14),
          "--backdrop-base-scale": scale(1.02),
          "--backdrop-grid-x": px(14),
          "--backdrop-grid-y": px(-54),
          "--backdrop-floor-y": px(12),
          "--backdrop-floor-scale": scale(1.04),
          "--backdrop-circuit-x": px(12),
          "--backdrop-circuit-y": px(-18),
          "--backdrop-circuit-scale": scale(1.03),
          "--backdrop-arcs-y": px(-8),
          "--backdrop-arc-rotate": deg(-3.5),
          "--backdrop-arc-scale": scale(1.03),
          "--backdrop-panel-x": px(16),
          "--backdrop-panel-y": px(-8),
          "--backdrop-panel-rotate": deg(-1.2),
          "--backdrop-orb-gold-x": px(24),
          "--backdrop-orb-gold-y": px(-28),
          "--backdrop-orb-gold-scale": scale(1.07),
          "--backdrop-orb-green-x": px(-12),
          "--backdrop-orb-green-y": px(14),
          "--backdrop-orb-green-scale": scale(1.05),
          "--hero-backdrop-y": px(-10),
          "--hero-backdrop-opacity": 0.94,
          duration: 1,
        },
        0,
      )
      .to(
        root,
        {
          "--backdrop-base-x": px(-10),
          "--backdrop-base-y": px(-30),
          "--backdrop-base-scale": scale(1.045),
          "--backdrop-grid-x": px(-22),
          "--backdrop-grid-y": px(-126),
          "--backdrop-floor-y": px(28),
          "--backdrop-floor-scale": scale(1.08),
          "--backdrop-circuit-x": px(-18),
          "--backdrop-circuit-y": px(-44),
          "--backdrop-circuit-scale": scale(1.06),
          "--backdrop-arcs-y": px(-20),
          "--backdrop-arc-rotate": deg(5.25),
          "--backdrop-arc-scale": scale(1.08),
          "--backdrop-panel-x": px(28),
          "--backdrop-panel-y": px(12),
          "--backdrop-panel-rotate": deg(1.9),
          "--backdrop-orb-gold-x": px(42),
          "--backdrop-orb-gold-y": px(-44),
          "--backdrop-orb-gold-scale": scale(1.11),
          "--backdrop-orb-green-x": px(-22),
          "--backdrop-orb-green-y": px(26),
          "--backdrop-orb-green-scale": scale(1.08),
          "--hero-backdrop-y": px(-18),
          "--hero-backdrop-opacity": 0.88,
          duration: 1,
        },
        1,
      )
      .to(
        root,
        {
          "--backdrop-base-x": px(10),
          "--backdrop-base-y": px(-44),
          "--backdrop-base-scale": scale(1.06),
          "--backdrop-grid-x": px(20),
          "--backdrop-grid-y": px(-194),
          "--backdrop-floor-y": px(42),
          "--backdrop-floor-scale": scale(1.11),
          "--backdrop-circuit-x": px(24),
          "--backdrop-circuit-y": px(-72),
          "--backdrop-circuit-scale": scale(1.08),
          "--backdrop-arcs-y": px(-32),
          "--backdrop-arc-rotate": deg(10.5),
          "--backdrop-arc-scale": scale(1.13),
          "--backdrop-panel-x": px(-18),
          "--backdrop-panel-y": px(-20),
          "--backdrop-panel-rotate": deg(-1.8),
          "--backdrop-orb-gold-x": px(60),
          "--backdrop-orb-gold-y": px(-70),
          "--backdrop-orb-gold-scale": scale(1.18),
          "--backdrop-orb-green-x": px(-30),
          "--backdrop-orb-green-y": px(38),
          "--backdrop-orb-green-scale": scale(1.12),
          "--hero-backdrop-y": px(-28),
          "--hero-backdrop-opacity": 0.8,
          duration: 0.9,
        },
        2,
      );

    return timeline;
  };

  const setupSceneFallback = () => {
    if (sceneSteps.length === 0) {
      return;
    }

    const stepObserver = new IntersectionObserver(
      (entries) => {
        let bestEntry = null;

        entries.forEach((entry) => {
          if (!entry.isIntersecting) {
            return;
          }
          if (!bestEntry || entry.intersectionRatio > bestEntry.intersectionRatio) {
            bestEntry = entry;
          }
        });

        if (bestEntry) {
          setActiveScene(bestEntry.target.dataset.sceneCopy);
        }
      },
      {
        threshold: [0.35, 0.55, 0.75],
        rootMargin: "-16% 0px -24% 0px",
      },
    );

    sceneSteps.forEach((step) => {
      stepObserver.observe(step);
    });

    setActiveScene(1);
  };

  const setupMotion = () => {
    if (!window.gsap || !window.ScrollTrigger || prefersReducedMotion.matches) {
      setupSceneFallback();
      return;
    }

    const gsap = window.gsap;
    const ScrollTrigger = window.ScrollTrigger;
    gsap.registerPlugin(ScrollTrigger);
    root.classList.add("motion-ready");

    gsap.from(".hero-copy .eyebrow", {
      y: 18,
      autoAlpha: 0,
      duration: 0.55,
      ease: "power2.out",
    });

    gsap.from(".hero-title-line", {
      y: 28,
      autoAlpha: 0,
      stagger: 0.08,
      duration: 0.72,
      ease: "power3.out",
      delay: 0.08,
    });

    gsap.from(".hero-copy .lede", {
      y: 22,
      autoAlpha: 0,
      duration: 0.7,
      ease: "power3.out",
      delay: 0.16,
    });

    gsap.from(".hero-actions .button", {
      y: 16,
      autoAlpha: 0,
      stagger: 0.08,
      duration: 0.55,
      ease: "power2.out",
      delay: 0.24,
    });

    gsap.from(".hero-stage", {
      autoAlpha: 0,
      clipPath: "inset(10% 8% 12% 8% round 2rem)",
      duration: 0.95,
      ease: "power3.out",
      delay: 0.14,
    });

    gsap.from(".hero-stage .hero-device", {
      y: 18,
      autoAlpha: 0,
      stagger: 0.08,
      duration: 0.72,
      ease: "power2.out",
      delay: 0.24,
    });

    gsap.from(".hero-stage .hero-transfer, .hero-stage .hero-mini-card", {
      autoAlpha: 0,
      stagger: 0.08,
      duration: 0.72,
      ease: "power2.out",
      delay: 0.3,
    });

    gsap.utils
      .toArray(
        ".section-flow .section-heading, .section-flow .story-scrollytelling, .section-feature-showcase .section-heading, .section-feature-showcase .feature-showcase, .section-chains .section-heading, .section-chains .chains-grid, .section-feature-band .feature-marquee, .section-feature-band .section-heading, .section-feature-band .utility-grid, .section-trust .section-heading, .section-trust .trust-grid",
      )
      .forEach((block) => {
        const yOffset = block.classList.contains("section-heading") ? 34 : 44;
        gsap.fromTo(
          block,
          {
            y: yOffset,
            autoAlpha: 0.18,
          },
          {
            y: 0,
            autoAlpha: 1,
            ease: "none",
            scrollTrigger: {
              trigger: block,
              start: "top 92%",
              end: "top 54%",
              scrub: 0.85,
              invalidateOnRefresh: true,
            },
          },
        );
      });

    gsap.utils
      .toArray(".feature-intro-card, .chain-card, .trust-card, .utility-card")
      .forEach((card) => {
        gsap.fromTo(card, {
          y: 26,
          autoAlpha: 0.3,
          scale: 0.985,
        }, {
          y: 0,
          autoAlpha: 1,
          scale: 1,
          ease: "none",
          scrollTrigger: {
            trigger: card,
            start: "top 92%",
            end: "top 68%",
            scrub: 0.75,
            invalidateOnRefresh: true,
          },
        });
      });

    const mm = gsap.matchMedia();

    mm.add("(max-width: 720px)", () => {
      const backdropTimeline = buildBackdropTimeline(gsap, ScrollTrigger, 0.62);

      if (!backdropTimeline) {
        return undefined;
      }

      return () => {
        if (backdropTimeline.scrollTrigger) {
          backdropTimeline.scrollTrigger.kill();
        }
        backdropTimeline.kill();
        resetBackdropMotion(gsap);
      };
    });

    mm.add("(min-width: 721px)", () => {
      const backdropTimeline = buildBackdropTimeline(gsap, ScrollTrigger, 1);

      if (!backdropTimeline) {
        return undefined;
      }

      return () => {
        if (backdropTimeline.scrollTrigger) {
          backdropTimeline.scrollTrigger.kill();
        }
        backdropTimeline.kill();
        resetBackdropMotion(gsap);
      };
    });

    mm.add("(min-width: 721px)", () => {
      if (!featureShowcase) {
        return undefined;
      }

      const showcaseTimeline = gsap.timeline({
        scrollTrigger: {
          trigger: featureShowcase,
          start: "top 76%",
          end: "bottom 34%",
          scrub: 0.8,
        },
      });

      showcaseTimeline
        .fromTo(
          ".showcase-orbit",
          {
            rotate: -18,
            scale: 0.88,
            opacity: 0.28,
          },
          {
            rotate: 120,
            scale: 1.06,
            opacity: 0.82,
            duration: 1.2,
          },
          0,
        )
        .fromTo(
          ".showcase-beam",
          {
            scaleX: 0.22,
            opacity: 0.18,
          },
          {
            scaleX: 1,
            opacity: 0.92,
            duration: 1,
          },
          0.08,
        )
        .fromTo(
          ".showcase-card-1",
          {
            x: -96,
            y: 50,
            rotate: -12,
            autoAlpha: 0.16,
          },
          {
            x: 0,
            y: 0,
            rotate: -7,
            autoAlpha: 1,
            duration: 1,
          },
          0,
        )
        .fromTo(
          ".showcase-card-2",
          {
            y: 72,
            scale: 0.9,
            autoAlpha: 0.12,
          },
          {
            y: 0,
            scale: 1,
            autoAlpha: 1,
            duration: 1,
          },
          0.08,
        )
        .fromTo(
          ".showcase-card-3",
          {
            x: 92,
            y: -34,
            rotate: 12,
            autoAlpha: 0.16,
          },
          {
            x: 0,
            y: 0,
            rotate: 7,
            autoAlpha: 1,
            duration: 1,
          },
          0.12,
        )
        .fromTo(
          ".showcase-spark",
          {
            y: 20,
            autoAlpha: 0,
          },
          {
            y: -18,
            autoAlpha: 1,
            stagger: 0.08,
            duration: 0.8,
          },
          0.2,
        );

      return () => {
        showcaseTimeline.kill();
      };
    });

    mm.add("(min-width: 960px)", () => {
      if (!flowSection || !flowPin) {
        return undefined;
      }

      root.classList.add("flow-desktop");
      const timeline = buildFlowTimeline();

      if (!timeline) {
        return undefined;
      }

      const trigger = ScrollTrigger.create({
        trigger: flowPin,
        start: "top top+=88",
        end: "+=2000",
        pin: true,
        scrub: 0.72,
        animation: timeline,
        anticipatePin: 1,
        invalidateOnRefresh: true,
        onUpdate: (self) => {
          syncSceneFromProgress(self.progress);
        },
      });

      setActiveScene(1);

      return () => {
        trigger.kill();
        timeline.kill();
        root.classList.remove("flow-desktop");
        setActiveScene(1);
      };
    });

    mm.add("(max-width: 959px)", () => {
      const timeline = buildFlowTimeline();
      const triggers = [];
      const targets = {
        1: 0,
        2: 0.58,
        3: 1,
      };

      if (!timeline) {
        return undefined;
      }

      const moveToScene = (scene) => {
        setActiveScene(scene);
        gsap.to(timeline, {
          progress: targets[scene],
          duration: 0.68,
          ease: "power2.inOut",
          overwrite: true,
        });
      };

      sceneSteps.forEach((step) => {
        const trigger = ScrollTrigger.create({
          trigger: step,
          start: "top 72%",
          end: "bottom 38%",
          onEnter: () => moveToScene(step.dataset.sceneCopy),
          onEnterBack: () => moveToScene(step.dataset.sceneCopy),
        });

        triggers.push(trigger);
      });

      moveToScene(1);

      return () => {
        triggers.forEach((trigger) => trigger.kill());
        timeline.kill();
        setActiveScene(1);
      };
    });
  };

  observeSections();
  setupTiltStage();
  setActiveScene(1);
  setupMotion();
})();
