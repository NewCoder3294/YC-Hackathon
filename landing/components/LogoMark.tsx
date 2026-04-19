export function LogoMark({ size = 40 }: { size?: number }) {
  return (
    <svg
      xmlns="http://www.w3.org/2000/svg"
      viewBox="0 0 64 64"
      width={size}
      height={size}
      fill="none"
      aria-hidden
    >
      <rect width="64" height="64" rx="12" fill="#0A0A0A" />
      <rect
        x="0.5"
        y="0.5"
        width="63"
        height="63"
        rx="11.5"
        stroke="#262626"
      />
      <g transform="translate(16 16)">
        <rect x="0" y="0" width="3" height="32" fill="#FAFAFA" />
        <rect x="7" y="4" width="3" height="10" fill="#FAFAFA" />
        <rect x="14" y="2" width="3" height="14" fill="#FAFAFA" />
        <rect x="21" y="6" width="3" height="6" fill="#EF4444" />
        <rect x="28" y="3" width="3" height="12" fill="#FAFAFA" />
        <rect x="7" y="18" width="3" height="10" fill="#FAFAFA" />
        <rect x="14" y="16" width="3" height="14" fill="#FAFAFA" />
        <rect x="21" y="20" width="3" height="6" fill="#FAFAFA" />
        <rect x="28" y="17" width="3" height="12" fill="#FAFAFA" />
      </g>
    </svg>
  );
}
