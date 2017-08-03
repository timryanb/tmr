# For the use of MPI
from mpi4py.libmpi cimport *
cimport mpi4py.MPI as MPI

# Import numpy 
cimport numpy as np
import numpy as np

# Ensure that numpy is initialized
np.import_array()

# Import the definition required for const strings
from libc.string cimport const_char
from libc.stdlib cimport malloc, free

# Import C methods for python
from cpython cimport PyObject, Py_INCREF

# Import the TACS module
from tacs.TACS cimport *

# Import the definitions
from TMR cimport *

# Include the mpi4py header
cdef extern from "mpi-compat.h":
   pass

# This wraps a C++ array with a numpy array for later useage
cdef inplace_array_1d(int nptype, int dim1, void *data_ptr,
                      PyObject *ptr):
   '''Return a numpy version of the array'''
   # Set the shape of the array
   cdef int size = 1
   cdef np.npy_intp shape[1]
   cdef np.ndarray ndarray

   # Set the first entry of the shape array
   shape[0] = <np.npy_intp>dim1
      
   # Create the array itself - Note that this function will not
   # delete the data once the ndarray goes out of scope
   ndarray = np.PyArray_SimpleNewFromData(size, shape,
                                          nptype, data_ptr)

   # Set the base class who owns the memory
   if ptr != NULL:
      ndarray.base = ptr

   return ndarray

cdef class Vertex:
    cdef TMRVertex *ptr
    def __cinit__(self):
        self.ptr = NULL
        
    def __dealloc__(self):
        if self.ptr:
            self.ptr.decref()

cdef _init_Vertex(TMRVertex *ptr):
    vertex = Vertex()
    vertex.ptr = ptr
    vertex.ptr.incref()
    return vertex

cdef class Edge:
   cdef TMREdge *ptr
   def __cinit__(self):
      self.ptr = NULL
      
   def __dealloc__(self):
      if self.ptr:
         self.ptr.decref()
   def setVertices(self, Vertex v1, Vertex v2):
      self.ptr.setVertices(v1.ptr, v2.ptr)

   def getVertices(self):
      cdef TMRVertex *v1 = NULL
      cdef TMRVertex *v2 = NULL
      self.ptr.getVertices(&v1, &v2)
      return _init_Vertex(v1), _init_Vertex(v2)
   
   def writeToVTK(self, char* filename):
      self.ptr.writeToVTK(filename)
      
cdef _init_Edge(TMREdge *ptr):
   edge = Edge()
   edge.ptr = ptr
   edge.ptr.incref()
   return edge

cdef class Face:
   cdef TMRFace *ptr
   def __cinit__(self):
      self.ptr = NULL
      
   def __dealloc__(self):
      if self.ptr:
         self.ptr.decref()
         
   def getNumEdgeLoops(self):
      return self.ptr.getNumEdgeLoops()
   
   def setMaster(self, Face f):
      self.ptr.setMaster(f.ptr)
      
cdef _init_Face(TMRFace *ptr):
   face = Face()
   face.ptr = ptr
   face.ptr.incref()
   return face

cdef class Volume:
   cdef TMRVolume *ptr
   def __cinit__(self):
      self.ptr = NULL
      # cdef int nfaces = len(faces)
      # cdef TMRFace **fce
      # fce = <TMRFace**>malloc(nfaces*sizeof(TMRFace*))
      # for i in range(nfaces):
      #    fce[i] = (<Face>faces[i]).ptr
      # self.ptr = new TMRVolume(nfaces, fce, NULL)
      # self.ptr.incref()
      
   def __dealloc__(self):
      if self.ptr:
         self.ptr.decref()
         
   def getFaces(self):
      cdef TMRFace **f
      cdef int num_faces = 0
      self.ptr.getFaces(&num_faces, &f, NULL)
      fce = inplace_array_1d(np.dtype(object), num_faces,
                             <void**>f, <PyObject*>self)
      return fce
   
   def writeToVTK(self, char* filename):
      self.ptr.writeToVTK(filename)
      
   def updateOrientation(self):
      self.ptr.updateOrientation()

cdef _init_Volume(TMRVolume *ptr):
   vol = Volume()
   vol.ptr = ptr
   vol.ptr.incref()
   return vol

cdef class Curve:
    cdef TMRCurve *ptr
    def __cinit__(self):
        self.ptr = NULL
        
    def __dealloc__(self):
        if self.ptr:
            self.ptr.decref()

    # def setVertices(self, Vertex v1, Vertex v2):
    #    self.ptr.setVertices(v1.ptr, v2.ptr)

    # def getVertices(self):
    #    cdef TMRVertex *v1 = NULL
    #    cdef TMRVertex *v2 = NULL
    #    self.ptr.getVertices(&v1, &v2)
    #    return _init_Vertex(v1), _init_Vertex(v2)
            
    def writeToVTK(self, char* filename):
        self.ptr.writeToVTK(filename)

cdef _init_Curve(TMRCurve *ptr):
    curve = Curve()
    curve.ptr = ptr
    curve.ptr.incref()
    return curve

cdef class Pcurve:
    cdef TMRPcurve *ptr
    def __cinit__(self):
        self.ptr = NULL
        
    def __dealloc__(self):
        if self.ptr:
            self.ptr.decref()

cdef class Surface:
    cdef TMRSurface *ptr
    def __cinit__(self):
        self.ptr = NULL
        
    def __dealloc__(self):
        if self.ptr:
            self.ptr.decref()
            
    def writeToVTK(self, char* filename):
        self.ptr.writeToVTK(filename)
        
    # def addCurveSegment(self, curves, direct):
    #     cdef int ncurves = len(curves)
    #     cdef int *_dir = NULL
    #     cdef TMRCurve **crvs = NULL
    #     _dir = <int*>malloc(ncurves*sizeof(int))
    #     crvs = <TMRCurve**>malloc(ncurves*sizeof(TMRCurve*))
    #     for i in range(ncurves):
    #         _dir[i] = direct[i]
    #         crvs[i] = (<Curve>curves[i]).ptr
    #     self.ptr.addCurveSegment(ncurves, crvs, _dir)
    #     free(_dir)
    #     free(crvs)

cdef _init_Surface(TMRSurface *ptr):
    surface = Surface()
    surface.ptr = ptr
    surface.ptr.incref()
    return surface

cdef class BsplineCurve(Curve):
    def __cinit__(self, np.ndarray[double, ndim=2, mode='c'] pts, int k=4):
        cdef int nctl = pts.shape[0]
        cdef ku = k
        if ku > nctl:
            ku = nctl
        cdef TMRPoint* p = <TMRPoint*>malloc(nctl*sizeof(TMRPoint))
        for i in range(nctl):
            p[i].x = pts[i,0]
            p[i].y = pts[i,1]
            p[i].z = pts[i,2]
        self.ptr = new TMRBsplineCurve(nctl, ku, p)
        self.ptr.incref()
        free(p)

cdef class BsplinePcurve(Pcurve):
    def __cinit__(self, np.ndarray[double, ndim=2, mode='c'] pts, int k=4):
        cdef int nctl = pts.shape[0]
        cdef ku = k
        if ku > nctl:
            ku = nctl
        self.ptr = new TMRBsplinePcurve(nctl, ku, <double*>pts.data)
        self.ptr.incref()

cdef class BsplineSurface(Surface):
    def __cinit__(self, np.ndarray[double, ndim=3, mode='c'] pts,
                  int ku=4, int kv=4):
        cdef int nx = pts.shape[0]
        cdef int ny = pts.shape[1]
        cdef kx = ku
        cdef ky = kv
        if kx > nx:
            kx = nx
        if ky > ny:
            ky = ny
        cdef TMRPoint* p = <TMRPoint*>malloc(nx*ny*sizeof(TMRPoint))
        for j in range(ny):
            for i in range(nx):
                p[i + j*nx].x = pts[i,j,0]
                p[i + j*nx].y = pts[i,j,1]
                p[i + j*nx].z = pts[i,j,2]
        self.ptr = new TMRBsplineSurface(nx, ny, kx, ky, p)
        self.ptr.incref()
        free(p)

# cdef class VertexFromPoint(Vertex):
#    def __cinit__(self, np.ndarray[double, ndim=1, mode='c'] pt):
#       cdef TMRPoint point
#       point.x = pt[0]
#       point.y = pt[1]
#       point.z = pt[2]
#       self.ptr = new TMRVertexFromPoint(point)
#       self.ptr.incref()

# cdef class VertexFromCurve(Vertex):
#    def __cinit__(self, Curve curve, double t):
#       self.ptr = new TMRVertexFromCurve(curve.ptr, t)
#       self.ptr.incref()

# cdef class VertexFromSurface(Vertex):
#    def __cinit__(self, Surface surf, double u, double v):
#       self.ptr = new TMRVertexFromSurface(surf.ptr, u, v)
#       self.ptr.incref()

# cdef class CurveFromSurface(Curve):
#    def __cinit__(self, Surface surf, Pcurve pcurve):
#       self.ptr = new TMRCurveFromSurface(surf.ptr, pcurve.ptr)
#       self.ptr.incref()

# cdef class CurveInterpolation:
#     cdef TMRCurveInterpolation *ptr
#     def __cinit__(self, np.ndarray[double, ndim=2, mode='c'] pts):
#         cdef int nctl = pts.shape[0]
#         cdef TMRPoint* p = <TMRPoint*>malloc(nctl*sizeof(TMRPoint))
#         for i in range(nctl):
#             p[i].x = pts[i,0]
#             p[i].y = pts[i,1]
#             p[i].z = pts[i,2]
#         self.ptr = new TMRCurveInterpolation(p, nctl)
#         self.ptr.incref()
#         free(p)

#     def __dealloc__(self):
#         if self.ptr:
#             self.ptr.decref()

#     def setNumControlPoints(self, int nctl):
#         self.ptr.setNumControlPoints(nctl)
#         return

#     def createCurve(self, int ku):
#         cdef TMRBsplineCurve *curve = self.ptr.createCurve(ku)
#         return _init_Curve(curve)

# cdef class CurveLofter:
#     cdef TMRCurveLofter *ptr
#     def __cinit__(self, curves):
#         cdef int ncurves = len(curves)
#         cdef TMRBsplineCurve **crvs = NULL
#         cdef TMRBsplineCurve *bspline = NULL
#         crvs = <TMRBsplineCurve**>malloc(ncurves*sizeof(TMRBsplineCurve*))
#         for i in range(ncurves):
#             bspline =  _dynamicBsplineCurve((<Curve>curves[i]).ptr)
#             if bspline != NULL:
#                crvs[i] = bspline
#             else:
#                raise ValueError('CurveLofter: Lofting curves must be BsplineCurves')
#         self.ptr = new TMRCurveLofter(crvs, ncurves)
#         self.ptr.incref()
#         free(crvs)

#     def __dealloc__(self):
#         if self.ptr:
#             self.ptr.decref()

#     def createSurface(self, int kv):
#         cdef TMRSurface *surf = self.ptr.createSurface(kv)
#         return _init_Surface(surf)

# cdef class Geometry:
#     cdef TMRGeometry *ptr
#     def __cinit__(self, vertices, curves, surfaces):
#         cdef int nvertices = len(vertices)
#         cdef int ncurves = len(curves)
#         cdef int nsurfaces = len(surfaces)
#         cdef TMRVertex **verts = NULL
#         cdef TMRCurve **crvs = NULL
#         cdef TMRSurface **surfs = NULL
#         verts = <TMRVertex**>malloc(nvertices*sizeof(TMRVertex*))
#         crvs = <TMRCurve**>malloc(ncurves*sizeof(TMRCurve*))
#         surfs = <TMRSurface**>malloc(nsurfaces*sizeof(TMRSurface*))
#         for i in range(nvertices):
#             verts[i] = (<Vertex>vertices[i]).ptr
#         for i in range(ncurves):
#             crvs[i] = (<Curve>curves[i]).ptr
#         for i in range(nsurfaces):
#             surfs[i] = (<Surface>surfaces[i]).ptr
#         self.ptr = new TMRGeometry(nvertices, verts, ncurves, crvs, 
#                                    nsurfaces, surfs)
#         self.ptr.incref()
#         free(verts)
#         free(crvs)
#         free(surfs)

#     def __dealloc__(self):
#         if self.ptr:
#             self.ptr.decref()

cdef class Model:
   cdef TMRModel *ptr
   def __cinit__(self):
      self.ptr = NULL
  
   def __dealloc__(self):
      if self.ptr:
         self.ptr.decref()
   
   def getVolumes(self):
      cdef TMRVolume **vol
      cdef int num_vol = 0
      self.ptr.getVolumes(&num_vol, &vol)
      volm = inplace_array_1d(np.dtype(object), num_vol,
                              <void**>vol, <PyObject*>self)
      return volm
   
cdef _init_Model(TMRModel* ptr):
   model = Model()
   model.ptr = ptr
   return model

cdef class MeshOptions:
   cdef TMRMeshOptions ptr
   def __cinit__(self):
      self.ptr = TMRMeshOptions()
      
   def __dealloc__(self):
      return
cdef class Mesh:
    cdef TMRMesh *ptr
    def __cinit__(self, MPI.Comm comm, Model geo):
       cdef MPI_Comm c_comm = NULL
       if comm is not None:
          c_comm = comm.ob_mpi
          self.ptr = new TMRMesh(c_comm,geo.ptr)
          self.ptr.incref()

    def __dealloc__(self):
       if self.ptr:
          self.ptr.decref()

    def mesh(self, double h):
        self.ptr.mesh(h)

    def getMeshPoints(self):
       cdef TMRPoint *X
       cdef int npts = 0
       npts = self.ptr.getMeshPoints(&X)
       Xp = np.zeros((npts, 3), dtype=np.double)
       for i in range(npts):
          Xp[i,0] = X[i].x
          Xp[i,1] = X[i].y
          Xp[i,2] = X[i].z
       return Xp

    def getMeshConnectivity(self):
       cdef const int *quads = NULL
       cdef const int *hexes = NULL
       cdef int nquads = 0
       cdef int nhexes = 0
       self.ptr.getMeshConnectivity(&nquads,&quads,
                                    &nhexes,&hexes)
       q = np.zeros((nquads, 4), dtype=np.int)
       for i in range(nquads):
          q[i,0] = quads[4*i]
          q[i,1] = quads[4*i+1]
          q[i,2] = quads[4*i+2]
          q[i,3] = quads[4*i+3]
       he = np.zeros((nhexes,8),dtype=np.int)
       for i in range(nhexes):
          he[i,0] = hexes[8*i]
          he[i,1] = hexes[8*i+1]
          he[i,2] = hexes[8*i+2]
          he[i,3] = hexes[8*i+3]
          he[i,4] = hexes[8*i+4]
          he[i,5] = hexes[8*i+5]
          he[i,6] = hexes[8*i+6]
          he[i,7] = hexes[8*i+7]
          
       return q, he

    def createModelFromMesh(self):
       cdef TMRModel *model = NULL
       model = self.ptr.createModelFromMesh()
       return _init_Model(model) 



cdef class Topology:
   cdef TMRTopology *ptr
   def __cinit__(self):
      self.ptr = NULL

cdef class QuadrantArray:
   cdef TMRQuadrantArray *ptr
   def __cinit__(self):
      self.ptr = NULL

   def __dealloc__(self):
      del self.ptr

cdef _init_QuadrantArray(TMRQuadrantArray *array):
   arr = QuadrantArray()
   arr.ptr = array
   return arr

cdef class QuadForest:
   cdef TMRQuadForest *ptr
   def __cinit__(self, MPI.Comm comm=None):
      cdef MPI_Comm c_comm = NULL
      self.ptr = NULL
      if comm is not None:
         c_comm = comm.ob_mpi
         self.ptr = new TMRQuadForest(c_comm)
         self.ptr.incref()

   def __dealloc__(self):
      self.ptr.decref()

   def setTopology(self, Topology topo):
      self.ptr.setTopology(topo.ptr)

   def repartition(self):
      self.ptr.repartition()

   def createTrees(self, int depth):
      self.ptr.createRandomTrees(depth)

   def refine(self, np.ndarray[int, ndim=1, mode='c'] refine):
      self.ptr.refine(<int*>refine.data)

   def duplicate(self):
      cdef TMRQuadForest *dup = NULL
      dup = self.ptr.duplicate()
      return _init_QuadForest(dup)

   def coarsen(self):
      cdef TMRQuadForest *dup = NULL
      dup = self.ptr.coarsen()
      return _init_QuadForest(dup)

   def balance(self, int btype):
      self.ptr.balance(btype)

   def createNodes(self, int order):
      self.ptr.createNodes(order)

   def getQuadsWithAttribute(self, char *attr):
      cdef TMRQuadrantArray *array = NULL
      array = self.ptr.getQuadsWithAttribute(attr)
      return _init_QuadrantArray(array)

   def getNodesWithAttribute(self, char *attr):
      cdef TMRQuadrantArray *array = NULL
      array = self.ptr.getNodesWithAttribute(attr)
      return _init_QuadrantArray(array)

cdef _init_QuadForest(TMRQuadForest* ptr):
    forest = QuadForest()
    forest.ptr = ptr
    forest.ptr.incref()
    return forest


cdef class OctantArray:
   cdef TMROctantArray *ptr
   def __cinit__(self):
      self.ptr = NULL

   def __dealloc__(self):
      del self.ptr

cdef _init_OctantArray(TMROctantArray *array):
   arr = OctantArray()
   arr.ptr = array
   return arr

cdef class OctForest:
   cdef TMROctForest *ptr
   def __cinit__(self, MPI.Comm comm=None):
      cdef MPI_Comm c_comm = NULL
      self.ptr = NULL
      if comm is not None:
         c_comm = comm.ob_mpi
         self.ptr = new TMROctForest(c_comm)
         self.ptr.incref()

   def __dealloc__(self):
      self.ptr.decref()

   def setTopology(self, Topology topo):
      self.ptr.setTopology(topo.ptr)

   def repartition(self):
      self.ptr.repartition()

   def createTrees(self, int depth):
      self.ptr.createRandomTrees(depth)

   def refine(self, np.ndarray[int, ndim=1, mode='c'] _refine):
      self.ptr.refine(<int*>_refine.data)

   def duplicate(self):
      cdef TMROctForest *dup = NULL
      dup = self.ptr.duplicate()
      return _init_OctForest(dup)

   def coarsen(self):
      cdef TMROctForest *dup = NULL
      dup = self.ptr.coarsen()
      return _init_OctForest(dup)

   def balance(self, int btype):
      self.ptr.balance(btype)

   def createNodes(self, int order):
      self.ptr.createNodes(order)

   def getOctsWithAttribute(self, char *attr):
      cdef TMROctantArray *array = NULL
      array = self.ptr.getOctsWithAttribute(attr)
      return _init_OctantArray(array)

   def getNodesWithAttribute(self, char *attr):
      cdef TMROctantArray *array = NULL
      array = self.ptr.getNodesWithAttribute(attr)
      return _init_OctantArray(array)
   
cdef _init_OctForest(TMROctForest* ptr):
    forest = OctForest()
    forest.ptr = ptr
    forest.ptr.incref()
    return forest

def LoadModel(char *filename):
   cdef TMRModel *model = TMR_LoadModelFromSTEPFile(filename)
   return _init_Model(model)
   
   
