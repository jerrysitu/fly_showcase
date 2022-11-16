module.exports = {
  content: ["./js/**/*.js", "../lib/*_web/**/*.*ex"],
  plugins: [
    require("@tailwindcss/forms"),
    require("@tailwindcss/typography"),
    require("tailwindcss-neumorphism"),
  ],
  theme: {
    extend: {
      animation: {
        "scale-in-center": "scale-in-center 0.3s ease-in-out",
      },
      keyframes: {
        "scale-in-center": {
          "0%": {
            transform: "scale(0)",
            opacity: "1",
          },
          to: {
            transform: "scale(1)",
            opacity: "1",
          },
        },
      },
    },
  },
};
