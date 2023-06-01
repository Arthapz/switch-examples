#include <stdlib.h>
#include <switch.h>

#include <iostream>
#include <format>
#include <string>
#include <string_view>
#include <array>

#include <EGL/egl.h>    // EGL library
#include <EGL/eglext.h> // EGL extensions
#include <glad/glad.h>  // glad library (OpenGL loader)

class OpenGLWindow {
    public:
        OpenGLWindow(NWindow *window) : m_window{window} {
            initDisplay();
            initContext();
            initSurface();

            // Connect the context to the surface
            eglMakeCurrent(m_display, m_surface, m_surface, m_context);
        }

        ~OpenGLWindow() {
            if(m_display) [[likely]] {
                eglMakeCurrent(m_display, EGL_NO_SURFACE, EGL_NO_SURFACE, EGL_NO_CONTEXT);

                if(m_surface) [[likely]]
                    eglDestroySurface(m_display, m_surface);

                if(m_context) [[likely]]
                    eglDestroyContext(m_display, m_context);

                eglTerminate(m_display);

                m_surface = nullptr;
                m_context = nullptr;
                m_display = nullptr;
            }

            m_window = nullptr;
        }

        OpenGLWindow(const OpenGLWindow &) = delete;
        auto operator=(const OpenGLWindow &) -> OpenGLWindow & = delete;

        OpenGLWindow(OpenGLWindow &&other) noexcept
            : m_window{std::exchange(other.m_window, nullptr)},
              m_display{std::exchange(other.m_display, nullptr)},
              m_context{std::exchange(other.m_context, nullptr)},
              m_surface{std::exchange(other.m_surface, nullptr)},
              m_config{other.m_config}
        {

        }

        auto operator=(OpenGLWindow &&other) noexcept -> OpenGLWindow & {
            if(this == &other) [[unlikely]]
                return *this;

            m_window = std::exchange(other.m_window, nullptr);
            m_display = std::exchange(other.m_display, nullptr);
            m_context = std::exchange(other.m_context, nullptr);
            m_surface = std::exchange(other.m_surface, nullptr);
            m_config = other.m_config;

            return *this;
        }

        auto update() -> void {
            eglSwapBuffers(m_display, m_surface);
        }

    private:
        auto initDisplay() -> void {
            m_display = eglGetDisplay(EGL_DEFAULT_DISPLAY);

            if(!m_display)
                throw std::string{"Failed to create egl display"};

            // Initialize the EGL display connection
            eglInitialize(m_display, nullptr, nullptr);

            // Select OpenGL (Core) as the desired graphics API
            if (eglBindAPI(EGL_OPENGL_API) == EGL_FALSE)
                throw std::format("Could not set API! error: {}", eglGetError());

            // Get an appropriate EGL framebuffer configuration
            auto configs_count = EGLint{0};
            static constexpr auto attr_list = std::array {
                EGL_RENDERABLE_TYPE, EGL_OPENGL_BIT,
                EGL_RED_SIZE,     8,
                EGL_GREEN_SIZE,   8,
                EGL_BLUE_SIZE,    8,
                EGL_ALPHA_SIZE,   8,
                EGL_DEPTH_SIZE,   24,
                EGL_STENCIL_SIZE, 8,
                EGL_NONE
            };

            eglChooseConfig(m_display, std::data(attr_list), &m_config, 1, &configs_count);

            if (configs_count == 0)
                throw std::format("No config found! error: {}", eglGetError());
        }

        auto initContext() -> void {
            // Create an EGL rendering context
            static constexpr auto attr_list = std::array {
                EGL_CONTEXT_OPENGL_PROFILE_MASK_KHR, EGL_CONTEXT_OPENGL_CORE_PROFILE_BIT_KHR,
                EGL_CONTEXT_MAJOR_VERSION_KHR, 4,
                EGL_CONTEXT_MINOR_VERSION_KHR, 3,
                EGL_NONE
            };

            m_context = eglCreateContext(m_display, m_config, EGL_NO_CONTEXT, std::data(attr_list));

            if (!m_context)
                throw std::format("Context creation failed! error: {}", eglGetError());
        }

        auto initSurface() -> void {
            // Create an EGL window surface
            m_surface = eglCreateWindowSurface(m_display, m_config, m_window, nullptr);
            if (!m_surface)
                throw std::format("Surface creation failed! error: {}", eglGetError());
        }

        NWindow *m_window;

        EGLDisplay m_display = nullptr;
        EGLContext m_context = nullptr;
        EGLSurface m_surface = nullptr;

        EGLConfig m_config;
};

static constexpr auto vs_shader = R"text(
    #version 330 core

    layout (location = 0) in vec3 aPos;
    layout (location = 1) in vec3 aColor;

    out vec3 ourColor;

    void main()
    {
        gl_Position = vec4(aPos.x, aPos.y, aPos.z, 1.0);
        ourColor = aColor;
    }
)text";

static constexpr auto fs_shader = R"text(
    #version 330 core

    in vec3 ourColor;

    out vec4 fragColor;

    void main()
    {
        fragColor = vec4(ourColor, 1.0f);
    }
)text";

auto createAndCompileShader(GLenum type, std::string_view source) {
    GLchar msg[512];

    GLuint handle = glCreateShader(type);
    if (!handle) [[unlikely]] {
        std::cout << std::format("{}: cannot create shader", type);
        return 0u;
    }

    auto length = static_cast<GLint>(std::size(source));
    auto raw_src = std::data(source);
    glShaderSource(handle, 1, &raw_src, &length);
    glCompileShader(handle);

    auto success = GLint{0};
    glGetShaderiv(handle, GL_COMPILE_STATUS, &success);

    if (!success) [[unlikely]] {
        auto msg = std::string{};
        auto size = 0;
        glGetShaderiv(handle, GL_INFO_LOG_LENGTH, &size);

        msg.resize(size);

        glGetShaderInfoLog(handle, size, nullptr, std::data(msg));

        std::cout << std::format("{}: {}", type, msg);

        glDeleteShader(handle);
        return 0u;
    }

    return handle;
}

struct Vertex {
    float position[3];
    float color[3];
};

static constexpr auto VERTICES = std::to_array<Vertex>({
    { { -0.5f, -0.5f, 0.0f }, { 1.0f, 0.0f, 0.0f } },
    { {  0.5f, -0.5f, 0.0f }, { 0.0f, 1.0f, 0.0f } },
    { {  0.0f,  0.5f, 0.0f }, { 0.0f, 0.0f, 1.0f } },
});


int main(int argc, char **argv) {
    auto initialized = true;

    auto window = std::optional<OpenGLWindow>{};
    try {
        window = OpenGLWindow{ nwindowGetDefault() };
    } catch(const std::string &error) {
        std::cout << "Error: " << error << std::endl;
        return EXIT_FAILURE;
    }

    gladLoadGL();

    padConfigureInput(1, HidNpadStyleSet_NpadStandard);

    PadState pad;
    padInitializeDefault(&pad);

    auto vertex_shader = createAndCompileShader(GL_VERTEX_SHADER, vs_shader);
    auto fragment_shader = createAndCompileShader(GL_FRAGMENT_SHADER, fs_shader);

    initialized = vertex_shader != 0;
    initialized = fragment_shader != 0;

    auto program = glCreateProgram();

    glAttachShader(program, vertex_shader);
    glAttachShader(program, fragment_shader);
    glLinkProgram(program);

    auto success = GLint{0};
    glGetProgramiv(program, GL_LINK_STATUS, &success);

    if(!success) {
        auto msg = std::string{};
        auto size = 0;
        glGetProgramiv(program, GL_INFO_LOG_LENGTH, &size);

        msg.resize(size);

        glGetProgramInfoLog(program, size, nullptr, std::data(msg));

        std::cout << std::format("Program link error: {}", msg);

        initialized = false;
    }

    if(vertex_shader)
        glDeleteShader(vertex_shader);

    if(fragment_shader)
        glDeleteShader(fragment_shader);

    auto vao = GLuint{0};
    glGenVertexArrays(1, &vao);

    auto vbo = GLuint{0};
    glGenBuffers(1, &vbo);

    // bind the Vertex Array Object first, then bind and set vertex buffer(s), and then configure vertex attributes(s).
    glBindVertexArray(vao);

    glBindBuffer(GL_ARRAY_BUFFER, vbo);
    glBufferData(GL_ARRAY_BUFFER, sizeof(VERTICES), std::data(VERTICES), GL_STATIC_DRAW);

    glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, sizeof(Vertex), std::bit_cast<void*>(offsetof(Vertex, position)));
    glEnableVertexAttribArray(0);

    glVertexAttribPointer(1, 3, GL_FLOAT, GL_FALSE, sizeof(Vertex), std::bit_cast<void*>(offsetof(Vertex, color)));
    glEnableVertexAttribArray(1);

    // note that this is allowed, the call to glVertexAttribPointer registered VBO as the vertex attribute's bound vertex buffer object so afterwards we can safely unbind
    glBindBuffer(GL_ARRAY_BUFFER, 0);

    while(appletMainLoop() && initialized) {
        padUpdate(&pad);

        const int kdown = padGetButtonsDown(&pad);

        if(kdown & HidNpadButton_Plus) break;

        glClearColor(0.2f, 0.3f, 0.3f, 1.0f);
        glClear(GL_COLOR_BUFFER_BIT);

        glUseProgram(program);
        glDrawArrays(GL_TRIANGLES, 0, 3);

        window->update();
    }

    if(vbo)
        glDeleteBuffers(1, &vbo);

    if(vao)
        glDeleteVertexArrays(1, &vao);

    if(program)
        glDeleteProgram(program);

    return EXIT_SUCCESS;
}

static int s_nxlinkSock = -1;

static void initNxLink()
{
    if (R_FAILED(socketInitializeDefault()))
        return;

    s_nxlinkSock = nxlinkStdio();
    if (s_nxlinkSock >= 0)
        std::cout << "printf output now goes to nxlink server";
    else
        socketExit();
}

static void deinitNxLink()
{
    if (s_nxlinkSock >= 0)
    {
        close(s_nxlinkSock);
        socketExit();
        s_nxlinkSock = -1;
    }
}

extern "C" void userAppInit()
{
    initNxLink();
}

extern "C" void userAppExit()
{
    deinitNxLink();
}