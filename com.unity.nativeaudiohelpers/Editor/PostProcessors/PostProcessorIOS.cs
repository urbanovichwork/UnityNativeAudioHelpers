using UnityEditor;
using UnityEditor.Build;
using UnityEditor.Build.Reporting;
using UnityEditor.iOS.Xcode;
using UnityEngine;

namespace NativeAudioHelper.Editor
{
    public class PostProcessorIOS : IPostprocessBuildWithReport
    {
        int IOrderedCallback.callbackOrder => 2;

        public void OnPostprocessBuild(BuildReport report)
        {
            if (report.summary.platform == BuildTarget.iOS)
            {
                Log($"{nameof(OnPostprocessBuild)} Started");
                WritePropertiesToProject(report.summary.outputPath);
                Log($"{nameof(OnPostprocessBuild)} Finished");
            }
        }

        private void WritePropertiesToProject(string path)
        {
            Log($"{nameof(WritePropertiesToProject)} {path}");
            var projPath = PBXProject.GetPBXProjectPath(path);
            var project = new PBXProject();
            project.ReadFromFile(projPath);

            var targetGuid = project.GetUnityMainTargetGuid();

            foreach (var framework in new[] { targetGuid, project.GetUnityFrameworkTargetGuid() })
            {
                Log($"Write to {framework}");
                project.AddFrameworkToProject(framework, "MediaPlayer.framework", true);
            }

            project.WriteToFile(projPath);
        }

        private static void Log(string message)
        {
            Debug.Log($"[PostProcessorIPhone]: {message}");
        }
    }
}