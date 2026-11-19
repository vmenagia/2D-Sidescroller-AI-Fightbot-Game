using Godot;
using Microsoft.ML.OnnxRuntime;
using Microsoft.ML.OnnxRuntime.Tensors;
using System.Collections.Generic;
using System.Linq;

namespace GodotONNX
{
	public partial class ONNXInference : GodotObject
	{
		private InferenceSession session;
		private string modelPath;
		private int batchSize;
		private string inputName;
		private string outputName;
		private SessionOptions SessionOpt;

		public int Initialize(string Path, int BatchSize)
		{
			modelPath = Path;
			batchSize = BatchSize;
			SessionOpt = SessionConfigurator.MakeConfiguredSessionOptions();
			session = LoadModel(modelPath);
			inputName = session.InputMetadata.Keys.First();
			outputName = session.OutputMetadata.Keys.First();
			return session.OutputMetadata[outputName].Dimensions[1];
		}

		public Godot.Collections.Array<float> Predict(Godot.Collections.Array<float> obs)
		{
			var obsData = new float[obs.Count];
			for (int i = 0; i < obs.Count; i++)
			{
				obsData[i] = obs[i];
			}

			var modelInputsList = new List<NamedOnnxValue>
			{
				NamedOnnxValue.CreateFromTensor(inputName, new DenseTensor<float>(obsData, new int[] { batchSize, obs.Count }))
			};

			try
			{
				using var results = session.Run(modelInputsList);
				var outputArray = new Godot.Collections.Array<float>();
				foreach (var result in results)
				{
					foreach (float f in result.AsEnumerable<float>())
					{
						outputArray.Add(f);
					}
				}
				return outputArray;
			}
			catch (OnnxRuntimeException e)
			{
				GD.Print("Error at inference: ", e);
				return null;
			}
		}

		public InferenceSession LoadModel(string Path)
		{
			using Godot.FileAccess file = FileAccess.Open(Path, Godot.FileAccess.ModeFlags.Read);
			byte[] model = file.GetBuffer((int)file.GetLength());
			return new InferenceSession(model, SessionOpt);
		}

		public void FreeDisposables()
		{
			session?.Dispose();
			SessionOpt?.Dispose();
		}
	}
}
